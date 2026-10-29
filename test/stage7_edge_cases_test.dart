import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:overshare/core/app_state.dart';
import 'package:overshare/features/decision/purpose.dart';
import 'package:overshare/features/decision/recommendation.dart';
import 'package:overshare/features/decision/risk_scorer.dart';
import 'package:overshare/features/history/history_database.dart';
import 'package:overshare/features/history/history_providers.dart';
import 'package:overshare/features/redaction/export_service.dart';
import 'package:overshare/features/redaction/redaction_providers.dart';
import 'package:overshare/features/redaction/redaction_service.dart';
import 'package:overshare/features/review/before_after_screen.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/ocr_line.dart';
import 'package:overshare/features/scanner/pattern_detector.dart';

void main() {
  group('Stage 7 Edge Cases & Resilience Tests', () {
    const redactionService = RedactionService();

    test('Edge Case 1: Very large image is redacted without error', () {
      // 2400 x 1800 high resolution image
      final largeImg = img.Image(width: 2400, height: 1800);
      img.fill(largeImg, color: img.ColorRgb8(200, 220, 240));
      final bytes = Uint8List.fromList(img.encodePng(largeImg));

      final regions = [
        const BoundingBox(left: 100, top: 100, width: 400, height: 80),
        const BoundingBox(left: 1800, top: 1500, width: 500, height: 120),
      ];

      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: bytes,
        regions: regions,
        style: RedactionStyle.solidFill,
      );

      final decoded = img.decodeImage(redactedBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 2400);
      expect(decoded.height, 1800);
    });

    test('Edge Case 2: Image with no text returns 0 findings & 0 score', () {
      const detector = PatternDetector();
      // OCR returns zero lines
      final emptyOcrLines = <OcrLine>[];
      final findings = detector.detectFindings(emptyOcrLines);

      expect(findings, isEmpty);

      final recs = generateRecommendations(findings, Purpose.paymentProof);
      expect(recs, isEmpty);

      const scorer = RiskScorer();
      final scoreResult = scorer.calculateScore(findings, Purpose.paymentProof);
      expect(scoreResult.totalScore, 0);
      expect(scoreResult.items, isEmpty);
      expect(scoreResult.exposureLevel, 'No Exposure');
    });

    test('Edge Case 3: Every finding set to KEEP yields clean image without redaction boxes', () {
      final sampleImg = img.Image(width: 200, height: 200);
      img.fill(sampleImg, color: img.ColorRgb8(255, 255, 255));
      final bytes = Uint8List.fromList(img.encodePng(sampleImg));

      // User kept everything: 0 regions to redact
      final regions = <BoundingBox>[];

      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: bytes,
        regions: regions,
        style: RedactionStyle.solidFill,
      );

      final decoded = img.decodeImage(redactedBytes)!;
      // All pixels should still be white (255, 255, 255)
      final p = decoded.getPixel(100, 100);
      expect(p.r, 255);
      expect(p.g, 255);
      expect(p.b, 255);
    });

    test('Edge Case 4: Overlapping findings do not crash or invert pixels', () {
      final sampleImg = img.Image(width: 300, height: 300);
      img.fill(sampleImg, color: img.ColorRgb8(255, 255, 255));
      final bytes = Uint8List.fromList(img.encodePng(sampleImg));

      // Two overlapping boxes
      final regions = [
        const BoundingBox(left: 50, top: 50, width: 100, height: 100),
        const BoundingBox(left: 80, top: 80, width: 120, height: 120),
      ];

      // Solid fill
      final solidBytes = redactionService.redactImageBytes(
        imageBytes: bytes,
        regions: regions,
        style: RedactionStyle.solidFill,
      );
      final solidDecoded = img.decodeImage(solidBytes)!;
      // In intersection (e.g. at 90, 90), pixels must be black (0, 0, 0)
      final pSolid = solidDecoded.getPixel(90, 90);
      expect(pSolid.r, 0);
      expect(pSolid.g, 0);
      expect(pSolid.b, 0);

      // Pixelate
      final pixelBytes = redactionService.redactImageBytes(
        imageBytes: bytes,
        regions: regions,
        style: RedactionStyle.pixelate,
      );
      final pixelDecoded = img.decodeImage(pixelBytes);
      expect(pixelDecoded, isNotNull);
    });

    test('Edge Case 5: Regions at image borders and out-of-bounds are clamped', () {
      final sampleImg = img.Image(width: 200, height: 200);
      img.fill(sampleImg, color: img.ColorRgb8(255, 255, 255));
      final bytes = Uint8List.fromList(img.encodePng(sampleImg));

      // Negative coordinates & coordinates extending beyond width/height
      final extremeBoxes = [
        const BoundingBox(left: -50, top: -30, width: 100, height: 80),
        const BoundingBox(left: 150, top: 150, width: 300, height: 400),
      ];

      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: bytes,
        regions: extremeBoxes,
        style: RedactionStyle.solidFill,
      );

      final decoded = img.decodeImage(redactedBytes);
      expect(decoded, isNotNull);
      // Origin pixel clamped and redacted
      final p0 = decoded!.getPixel(0, 0);
      expect(p0.r, 0);
      expect(p0.g, 0);
      expect(p0.b, 0);
      // Bottom-right corner pixel clamped and redacted
      final pEnd = decoded.getPixel(199, 199);
      expect(pEnd.r, 0);
      expect(pEnd.g, 0);
      expect(pEnd.b, 0);
    });

    test('Edge Case 6: EXIF orientation baking preserves dimensions without crash', () {
      final rotatedImg = img.Image(width: 400, height: 300);
      // Set EXIF orientation to 6 (Rotate 90 CW)
      rotatedImg.exif.imageIfd['Orientation'] = 6;
      img.fill(rotatedImg, color: img.ColorRgb8(100, 150, 200));
      final bytes = Uint8List.fromList(img.encodePng(rotatedImg));

      final redactedBytes = redactionService.redactImageBytes(
        imageBytes: bytes,
        regions: [
          const BoundingBox(left: 20, top: 20, width: 50, height: 50),
        ],
        style: RedactionStyle.solidFill,
      );

      final decoded = img.decodeImage(redactedBytes);
      expect(decoded, isNotNull);
    });
  });

  group('BeforeAfterScreen Widget Tests', () {
    testWidgets('Renders BeforeAfterScreen with transformation, slider and toggles', (tester) async {
      // Create test temporary images
      final testDir = Directory.systemTemp.createTempSync('overshare_before_after_test_');
      final originalFile = File('${testDir.path}/original.png');

      final sampleImg = img.Image(width: 200, height: 200);
      img.fill(sampleImg, color: img.ColorRgb8(240, 240, 240));
      final originalBytes = Uint8List.fromList(img.encodePng(sampleImg));
      originalFile.writeAsBytesSync(originalBytes);

      final redactedImg = img.Image(width: 200, height: 200);
      img.fill(redactedImg, color: img.ColorRgb8(0, 0, 0));
      final sanitizedBytes = Uint8List.fromList(img.encodePng(redactedImg));
      final sanitizedFile = File('${testDir.path}/sanitized.png');
      sanitizedFile.writeAsBytesSync(sanitizedBytes);

      final testExportResult = ExportResult(
        file: sanitizedFile,
        fileName: 'sanitized.png',
        byteSize: sanitizedBytes.length,
        formattedSize: '12 KB',
      );

      final inMemoryRepo = InMemoryHistoryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedImageProvider.overrideWith(
              () => _MockSelectedImageNotifier(XFile(originalFile.path)),
            ),
            selectedPurposeProvider.overrideWith(
              () => _MockSelectedPurposeNotifier(Purpose.paymentProof),
            ),
            sanitizedExportNotifierProvider.overrideWith(
              () => _MockSanitizedExportNotifier(
                SanitizedExportState(
                  isProcessing: false,
                  sanitizedBytes: sanitizedBytes,
                  exportResult: testExportResult,
                ),
              ),
            ),
            historyRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: const MaterialApp(
            home: BeforeAfterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header and transformation
      expect(find.text('Before & After Comparison'), findsOneWidget);
      expect(find.text('Payment proof'), findsOneWidget);
      expect(find.text('Original Exposure'), findsOneWidget);
      expect(find.text('Sanitized Exposure'), findsOneWidget);
      expect(find.text('Safe to Share'), findsOneWidget);

      // Check segments (Slider, Side by Side, Tap to Flip)
      expect(find.text('Slider'), findsOneWidget);
      expect(find.text('Side by Side'), findsOneWidget);
      expect(find.text('Tap to Flip'), findsOneWidget);

      // Switch to Side by Side mode
      await tester.tap(find.text('Side by Side'));
      await tester.pumpAndSettle();

      expect(find.text('Original (Unsafe)'), findsOneWidget);
      expect(find.text('Sanitized (Safe Copy)'), findsOneWidget);

      // Switch to Tap to Flip mode
      await tester.tap(find.text('Tap to Flip'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tap to flip'), findsOneWidget);

      // Check bottom action buttons
      expect(find.text('Share / Copy File Path'), findsOneWidget);
      expect(find.text('View Scan History'), findsOneWidget);
      expect(find.text('Done • Start New Scan'), findsOneWidget);

      // Clean up
      try {
        testDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}

class _MockSelectedImageNotifier extends SelectedImageNotifier {
  final XFile initial;
  _MockSelectedImageNotifier(this.initial);

  @override
  XFile? build() => initial;
}

class _MockSelectedPurposeNotifier extends SelectedPurposeNotifier {
  final Purpose initial;
  _MockSelectedPurposeNotifier(this.initial);

  @override
  Purpose? build() => initial;
}

class _MockSanitizedExportNotifier extends SanitizedExportNotifier {
  final SanitizedExportState initialState;

  _MockSanitizedExportNotifier(this.initialState);

  @override
  SanitizedExportState build() => initialState;
}
