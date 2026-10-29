import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:overshare/features/redaction/export_service.dart';
import 'package:overshare/features/redaction/metadata_service.dart';
import 'package:overshare/features/redaction/redaction_service.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';

void main() {
  const redactionService = RedactionService();
  const metadataService = MetadataService();

  /// Generates a test image with distinct gradient pixels
  Uint8List createTestImageBytes({int width = 100, int height = 100}) {
    final image = img.Image(width: width, height: height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        image.setPixelRgba(
          x,
          y,
          (x * 2) % 256,
          (y * 2) % 256,
          (x + y) % 256,
          255,
        );
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  group('RedactionService - Solid Fill Tests', () {
    test('Pixels inside region become uniform solid black, pixels outside remain unchanged', () {
      final originalBytes = createTestImageBytes(width: 100, height: 100);
      final originalImage = img.decodeImage(originalBytes)!;

      const region = BoundingBox(left: 30, top: 30, width: 40, height: 40);

      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: originalBytes,
        regions: [region],
        style: RedactionStyle.solidFill,
        padding: 0,
      );

      final redactedImage = img.decodeImage(redactedBytes)!;

      // 1. Pixels inside region [30..70, 30..70] must be uniform solid black (0, 0, 0, 255)
      for (int y = 30; y <= 70; y++) {
        for (int x = 30; x <= 70; x++) {
          final p = redactedImage.getPixel(x, y);
          expect(p.r.toInt(), 0, reason: 'Red pixel at ($x, $y) must be 0');
          expect(p.g.toInt(), 0, reason: 'Green pixel at ($x, $y) must be 0');
          expect(p.b.toInt(), 0, reason: 'Blue pixel at ($x, $y) must be 0');
          expect(p.a.toInt(), 255);

          // Must differ from original pixel
          final origP = originalImage.getPixel(x, y);
          expect(
            origP.r.toInt() != 0 || origP.g.toInt() != 0 || origP.b.toInt() != 0,
            isTrue,
          );
        }
      }

      // 2. Pixels outside region [0..25, 0..25] must remain identical to original
      for (int y = 0; y <= 25; y++) {
        for (int x = 0; x <= 25; x++) {
          final p = redactedImage.getPixel(x, y);
          final origP = originalImage.getPixel(x, y);
          expect(p.r.toInt(), origP.r.toInt());
          expect(p.g.toInt(), origP.g.toInt());
          expect(p.b.toInt(), origP.b.toInt());
          expect(p.a.toInt(), origP.a.toInt());
        }
      }
    });
  });

  group('RedactionService - Pixelate Tests', () {
    test('Pixels inside region are heavily blocked into mosaic blocks', () {
      final originalBytes = createTestImageBytes(width: 100, height: 100);
      const region = BoundingBox(left: 20, top: 20, width: 40, height: 40);
      const blockSize = 8;

      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: originalBytes,
        regions: [region],
        style: RedactionStyle.pixelate,
        padding: 0,
        pixelateBlockSize: blockSize,
      );

      final redactedImage = img.decodeImage(redactedBytes)!;

      // Verify that every pixel within an 8x8 block [20..27, 20..27] has the EXACT same color
      final samplePixel = redactedImage.getPixel(20, 20);
      final r = samplePixel.r.toInt();
      final g = samplePixel.g.toInt();
      final b = samplePixel.b.toInt();

      for (int y = 20; y < 28; y++) {
        for (int x = 20; x < 28; x++) {
          final p = redactedImage.getPixel(x, y);
          expect(p.r.toInt(), r, reason: 'Mosaic block pixels must be uniform at ($x, $y)');
          expect(p.g.toInt(), g);
          expect(p.b.toInt(), b);
        }
      }

      // Pixels outside region remain unchanged
      final originalImage = img.decodeImage(originalBytes)!;
      final outP = redactedImage.getPixel(5, 5);
      final origOutP = originalImage.getPixel(5, 5);
      expect(outP.r.toInt(), origOutP.r.toInt());
      expect(outP.g.toInt(), origOutP.g.toInt());
      expect(outP.b.toInt(), origOutP.b.toInt());
    });
  });

  group('RedactionService - Boundary Clamping Tests', () {
    test('Regions partly or completely outside image dimensions do not crash', () {
      final originalBytes = createTestImageBytes(width: 100, height: 100);

      const partlyOffTopLeft = BoundingBox(left: -50, top: -50, width: 80, height: 80);
      const partlyOffBottomRight = BoundingBox(left: 80, top: 80, width: 100, height: 100);
      const completelyOutside = BoundingBox(left: -500, top: -500, width: 50, height: 50);

      expect(() {
        redactionService.redactImageBytes(
          imageBytes: originalBytes,
          regions: [partlyOffTopLeft, partlyOffBottomRight, completelyOutside],
          style: RedactionStyle.solidFill,
        );
      }, returnsNormally);

      expect(() {
        redactionService.redactImageBytes(
          imageBytes: originalBytes,
          regions: [partlyOffTopLeft, partlyOffBottomRight, completelyOutside],
          style: RedactionStyle.pixelate,
        );
      }, returnsNormally);
    });
  });

  group('MetadataService & Stripping Tests', () {
    test('Image with EXIF is stripped of all metadata upon redaction', () {
      // 1. Create image with custom EXIF tags
      final image = img.Image(width: 50, height: 50);
      image.exif.imageIfd[0x010F] = 'Apple'; // Make
      image.exif.imageIfd[0x0110] = 'iPhone 15 Pro'; // Model
      image.exif.imageIfd[0x0132] = '2026:10:24 12:00:00'; // DateTime

      // Encode as JPEG to preserve EXIF in source
      final originalBytesWithExif = Uint8List.fromList(img.encodeJpg(image));

      // 2. Verify MetadataService extracts the original EXIF tags
      final extracted = metadataService.extractMetadata(originalBytesWithExif);
      expect(extracted.any((m) => m.label == 'Manufacturer' && m.value == 'Apple'), isTrue);
      expect(extracted.any((m) => m.label == 'Device Model' && m.value == 'iPhone 15 Pro'), isTrue);

      // 3. Redact image
      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: originalBytesWithExif,
        regions: [const BoundingBox(left: 10, top: 10, width: 20, height: 20)],
      );

      // 4. Verify no EXIF remains
      expect(metadataService.verifyExifStripped(redactedBytes), isTrue);
      final postRedactionMetadata = metadataService.extractMetadata(redactedBytes);
      expect(postRedactionMetadata, isEmpty);
    });
  });

  group('ExportService & Immutability Tests', () {
    test('Output is saved to a new file and original file is untouched', () async {
      // Create a temporary mock original file
      final tempDir = Directory.systemTemp.createTempSync('overshare_orig_test');
      final exportService = ExportService(targetDirectory: tempDir);
      final originalFile = File('${tempDir.path}/original.png');
      final origBytes = createTestImageBytes(width: 50, height: 50);
      originalFile.writeAsBytesSync(origBytes);

      final originalLengthBefore = originalFile.lengthSync();
      final originalModifiedBefore = originalFile.lastModifiedSync();

      // Redact bytes
      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: origBytes,
        regions: [const BoundingBox(left: 5, top: 5, width: 20, height: 20)],
      );

      // Save sanitized copy
      final result = await exportService.saveSanitizedImage(redactedBytes);

      // Verify sanitized file exists and has different path
      expect(result.file.existsSync(), isTrue);
      expect(result.file.path, isNot(equals(originalFile.path)));
      expect(result.file.lengthSync(), greaterThan(0));

      // Verify original file is 100% untouched
      expect(originalFile.existsSync(), isTrue);
      expect(originalFile.lengthSync(), equals(originalLengthBefore));
      expect(originalFile.lastModifiedSync(), equals(originalModifiedBefore));
      expect(originalFile.readAsBytesSync(), equals(origBytes));

      // Cleanup
      tempDir.deleteSync(recursive: true);
      if (result.file.existsSync()) {
        result.file.deleteSync();
      }
    });
  });
}
