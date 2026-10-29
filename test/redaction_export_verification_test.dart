import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:overshare/features/redaction/export_service.dart';
import 'package:overshare/features/redaction/metadata_service.dart';
import 'package:overshare/features/redaction/redaction_service.dart';
import 'package:overshare/features/redaction/saver/export_saver.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';

class MockTestSaver implements ExportSaver {
  Uint8List? savedBytes;
  String? savedFileName;

  @override
  Future<String> saveImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    savedBytes = bytes;
    savedFileName = fileName;
    return 'mock://sanitized/$fileName';
  }
}

void main() {
  group('RedactionService - Pixel Modification & Image Encoding', () {
    late RedactionService redactionService;
    late MetadataService metadataService;
    late Uint8List testImageBytes;

    setUp(() {
      redactionService = const RedactionService();
      metadataService = const MetadataService();

      // Create a 100x100 RGB image with white background (255, 255, 255)
      final image = img.Image(width: 100, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      // Add red patch in region (20, 20) to (50, 50)
      for (int y = 20; y <= 50; y++) {
        for (int x = 20; x <= 50; x++) {
          image.setPixelRgb(x, y, 255, 0, 0);
        }
      }
      testImageBytes = Uint8List.fromList(img.encodePng(image));
    });

    test('Solid Black Fill permanently overwrites pixels to pure black', () {
      const region = BoundingBox(left: 20, top: 20, width: 30, height: 30);
      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: testImageBytes,
        regions: [region],
        style: RedactionStyle.solidFill,
        padding: 0,
      );

      // Reopen and decode the exported image
      final decoded = img.decodeImage(redactedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 100);
      expect(decoded.height, 100);

      // Verify every pixel inside the region is solid black (0, 0, 0)
      for (int y = 20; y <= 50; y++) {
        for (int x = 20; x <= 50; x++) {
          final p = decoded.getPixel(x, y);
          expect(p.r, 0, reason: 'Red channel at ($x, $y) must be 0');
          expect(p.g, 0, reason: 'Green channel at ($x, $y) must be 0');
          expect(p.b, 0, reason: 'Blue channel at ($x, $y) must be 0');
        }
      }

      // Verify pixels outside the region remain intact (white: 255, 255, 255)
      final outsidePixel = decoded.getPixel(10, 10);
      expect(outsidePixel.r, 255);
      expect(outsidePixel.g, 255);
      expect(outsidePixel.b, 255);
    });

    test('Heavy Pixelation averages colors permanently and removes individual details', () {
      const region = BoundingBox(left: 20, top: 20, width: 30, height: 30);
      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: testImageBytes,
        regions: [region],
        style: RedactionStyle.pixelate,
        padding: 0,
        pixelateBlockSize: 8,
      );

      final decoded = img.decodeImage(redactedBytes);
      expect(decoded, isNotNull);

      // Verify the region has uniform block values and is non-transparent
      final p1 = decoded!.getPixel(21, 21);
      final p2 = decoded.getPixel(22, 22);
      expect(p1.r, equals(p2.r));
      expect(p1.g, equals(p2.g));
      expect(p1.b, equals(p2.b));
      expect(p1.a, 255);
    });

    test('Coordinate padding and clamping safely handles boundary boxes', () {
      // Region exceeding image dimensions on all sides
      const outOfBoundsRegion = BoundingBox(left: -20, top: -20, width: 200, height: 200);

      expect(
        () => redactionService.redactImageBytes(
          imageBytes: testImageBytes,
          regions: [outOfBoundsRegion],
          style: RedactionStyle.solidFill,
          padding: 8,
        ),
        returnsNormally,
      );
    });

    test('verifyRedactionApplied returns true for modified image and false for unredacted', () {
      const region = BoundingBox(left: 20, top: 20, width: 30, height: 30);

      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: testImageBytes,
        regions: [region],
        style: RedactionStyle.solidFill,
      );

      final verifiedSuccess = redactionService.verifyRedactionApplied(
        originalBytes: testImageBytes,
        redactedBytes: redactedBytes,
        regions: [region],
        style: RedactionStyle.solidFill,
      );
      expect(verifiedSuccess, isTrue);

      // Testing unredacted image against the expected region must fail verification
      final verifiedFailure = redactionService.verifyRedactionApplied(
        originalBytes: testImageBytes,
        redactedBytes: testImageBytes,
        regions: [region],
        style: RedactionStyle.solidFill,
      );
      expect(verifiedFailure, isFalse);
    });

    test('EXIF metadata is cleared and verified stripped on export', () {
      const region = BoundingBox(left: 10, top: 10, width: 20, height: 20);
      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: testImageBytes,
        regions: [region],
      );

      final isClean = metadataService.verifyExifStripped(redactedBytes);
      expect(isClean, isTrue);
    });
  });

  group('ExportService & Saver Platform Abstraction Tests', () {
    test('ExportService delegates to saver and formats file size accurately', () async {
      final mockSaver = MockTestSaver();
      final exportService = ExportService(saver: mockSaver);

      final dummyBytes = Uint8List(1024 * 50); // 50 KB
      final result = await exportService.saveSanitizedImage(dummyBytes);

      expect(result.fileName, startsWith('overshare_safe_'));
      expect(result.fileName, endsWith('.png'));
      expect(result.filePath, startsWith('mock://sanitized/'));
      expect(result.byteSize, 1024 * 50);
      expect(result.formattedSize, '50.0 KB');
      expect(mockSaver.savedBytes, dummyBytes);
      expect(mockSaver.savedFileName, result.fileName);
    });
  });
}
