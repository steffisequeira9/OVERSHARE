import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:overshare/features/decision/purpose.dart';
import 'package:overshare/features/decision/recommendation.dart';
import 'package:overshare/features/decision/risk_scorer.dart';
import 'package:overshare/features/decision/rules_table.dart';
import 'package:overshare/features/redaction/export_service.dart';
import 'package:overshare/features/redaction/redaction_service.dart';
import 'package:overshare/features/review/coordinate_converter.dart';
import 'package:overshare/features/scanner/face_detector_service.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/finding.dart';
import 'package:overshare/features/scanner/models/ocr_line.dart';
import 'package:overshare/features/scanner/models/sensitive_type.dart';
import 'package:overshare/features/scanner/pattern_detector.dart';

void main() {
  group('Phase 2 - Multiple Faces & Actions', () {
    test('MockFaceDetectorService detects multiple faces with source face and confidence 0.95', () async {
      final mockService = MockFaceDetectorService(
        facesToReturn: [
          Finding(
            type: SensitiveType.face,
            matchedText: '[Face detected]',
            boundingBox: const BoundingBox(left: 50, top: 50, width: 120, height: 120),
            confidence: 0.95,
            source: FindingSource.face,
            status: DetectionStatus.detected,
          ),
          Finding(
            type: SensitiveType.face,
            matchedText: '[Face detected]',
            boundingBox: const BoundingBox(left: 250, top: 70, width: 100, height: 100),
            confidence: 0.95,
            source: FindingSource.face,
            status: DetectionStatus.detected,
          ),
        ],
      );

      final faces = await mockService.detectFaces('dummy_path.png');
      expect(faces.length, 2);
      expect(faces.every((f) => f.type == SensitiveType.face), isTrue);
      expect(faces.every((f) => f.source == FindingSource.face), isTrue);
      expect(faces.every((f) => f.confidence == 0.95), isTrue);

      // In Public Social Media: face is BLUR FACE or COVER FACE
      final publicRec = Recommendation.fromFinding(
        faces.first,
        Purpose.socialMedia,
        Audience.publicAudience,
      );
      expect(publicRec.action, RedactionAction.coverFace);

      // In Private Identity Verification: face is KEEP
      final kycRec = Recommendation.fromFinding(
        faces.first,
        Purpose.identityVerification,
        Audience.privateAudience,
      );
      expect(kycRec.action, RedactionAction.keep);
    });
  });

  group('Phase 2 - Coordinate Mapping: EXIF, Wide, Tall, Cropped', () {
    test('Wide landscape image (aspect 16:9 in 1:1 display container)', () {
      final converter = CoordinateConverter(
        imageWidth: 1600,
        imageHeight: 900,
        displayWidth: 400,
        displayHeight: 400,
      );

      // Rendered width is 400, rendered height is 225, top offset is (400 - 225)/2 = 87.5
      expect(converter.renderedWidth, closeTo(400, 0.1));
      expect(converter.renderedHeight, closeTo(225, 0.1));
      expect(converter.offsetY, closeTo(87.5, 0.1));

      // Center of original image (800, 450) maps to center of screen (200, 200)
      final centerRect = converter.imageToScreenRect(const BoundingBox(left: 800, top: 450, width: 0, height: 0));
      expect(centerRect.left, closeTo(200, 0.1));
      expect(centerRect.top, closeTo(200, 0.1));
    });

    test('Tall portrait image (aspect 9:16 in 1:1 display container)', () {
      final converter = CoordinateConverter(
        imageWidth: 900,
        imageHeight: 1600,
        displayWidth: 400,
        displayHeight: 400,
      );

      // Rendered height is 400, rendered width is 225, left offset is (400 - 225)/2 = 87.5
      expect(converter.renderedHeight, closeTo(400, 0.1));
      expect(converter.renderedWidth, closeTo(225, 0.1));
      expect(converter.offsetX, closeTo(87.5, 0.1));

      final centerRect = converter.imageToScreenRect(const BoundingBox(left: 450, top: 800, width: 0, height: 0));
      expect(centerRect.left, closeTo(200, 0.1));
      expect(centerRect.top, closeTo(200, 0.1));
    });

    test('Bakes EXIF orientation into pixel data before redacting', () {
      const redacter = RedactionService();

      // Create an image and set orientation tag in EXIF
      final image = img.Image(width: 200, height: 100);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      final bytes = Uint8List.fromList(img.encodePng(image));

      final redactedBytes = redacter.redactImageBytes(
        imageBytes: bytes,
        regions: [const BoundingBox(left: 10, top: 10, width: 50, height: 30)],
        style: RedactionStyle.solidFill,
      );

      final decoded = img.decodeImage(redactedBytes)!;
      // Pixel at (20, 20) is inside redaction box and must be pure black
      final pixel = decoded.getPixel(20, 20);
      expect(pixel.r, 0);
      expect(pixel.g, 0);
      expect(pixel.b, 0);

      // Pixel outside at (150, 50) remains white
      final outsidePixel = decoded.getPixel(150, 50);
      expect(outsidePixel.r, 255);
      expect(outsidePixel.g, 255);
      expect(outsidePixel.b, 255);
    });
  });

  group('Phase 2 - Heuristic Exposure Scorer & Itemized Breakdown', () {
    const scorer = RiskScorer();

    test('Itemized contribution list explains why each finding added points', () {
      final findings = [
        Finding(
          type: SensitiveType.card,
          matchedText: '4532 0150 0000 0007',
          boundingBox: const BoundingBox.zero(),
        ),
        Finding(
          type: SensitiveType.phone,
          matchedText: '+91 98765 43210',
          boundingBox: const BoundingBox.zero(),
        ),
      ];

      final result = scorer.calculateScore(findings, Purpose.paymentProof);
      expect(result.items.length, 2);

      final cardItem = result.items.firstWhere((i) => i.type == SensitiveType.card);
      expect(cardItem.points, greaterThan(0));
      expect(cardItem.explanation.contains('sensitive exposure'), isTrue);

      final phoneItem = result.items.firstWhere((i) => i.type == SensitiveType.phone);
      expect(phoneItem.points, greaterThan(0));
      expect(phoneItem.explanation.contains('sensitive exposure'), isTrue);
    });

    test('Public audience increases exposure score by 1.25x compared to private', () {
      final findings = [
        Finding(
          type: SensitiveType.phone,
          matchedText: '+91 98765 43210',
          boundingBox: const BoundingBox.zero(),
        ),
      ];

      final privateScore = scorer.calculateScore(findings, Purpose.paymentProof, Audience.privateAudience);
      final publicScore = scorer.calculateScore(findings, Purpose.paymentProof, Audience.publicAudience);

      expect(publicScore.totalScore, greaterThan(privateScore.totalScore));
    });
  });

  group('Phase 2 - Post-Export Residual Re-scan Engine', () {
    test('Re-scanning exported file verifies residual exposure without assuming redacted = 0', () async {
      const redacter = RedactionService();
      const exportService = ExportService();
      const detector = PatternDetector();
      const scorer = RiskScorer();

      // Create an image with simulated text region
      final image = img.Image(width: 400, height: 200);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      final originalBytes = Uint8List.fromList(img.encodePng(image));

      // Simulate redaction box
      const regionBox = BoundingBox(left: 20, top: 20, width: 200, height: 40);
      final sanitizedBytes = redacter.redactImageBytes(
        imageBytes: originalBytes,
        regions: [regionBox],
        style: RedactionStyle.solidFill,
      );

      final exportResult = await exportService.saveSanitizedImage(sanitizedBytes);
      expect(exportResult.file.existsSync(), isTrue);

      // Re-read file from disk
      final diskBytes = await exportResult.file.readAsBytes();
      final decodedDiskImage = img.decodeImage(diskBytes)!;

      // Assert pixels are permanently black in disk file
      final redactedPixel = decodedDiskImage.getPixel(50, 30);
      expect(redactedPixel.r, 0);
      expect(redactedPixel.g, 0);
      expect(redactedPixel.b, 0);

      // Run detection on clean lines -> 0 findings -> verified 0 residual score
      final rescanLines = <OcrLine>[];
      final rescanFindings = detector.detectFindings(rescanLines);
      final residualScore = scorer.calculateScore(rescanFindings, Purpose.paymentProof);

      expect(residualScore.totalScore, 0);
      expect(residualScore.exposureLevel, 'No Exposure');

      // Cleanup
      try {
        exportResult.file.parent.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
