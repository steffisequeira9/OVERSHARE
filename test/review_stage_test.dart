import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:overshare/core/app_state.dart';
import 'package:overshare/features/decision/purpose.dart';
import 'package:overshare/features/decision/rules_table.dart';
import 'package:overshare/features/review/coordinate_converter.dart';
import 'package:overshare/features/review/models/review_state.dart';
import 'package:overshare/features/review/review_notifier.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/ocr_line.dart';
import 'package:overshare/features/scanner/ocr_service.dart';
import 'package:overshare/features/scanner/scanner_providers.dart';

void main() {
  group('CoordinateConverter Tests', () {
    test('Wide landscape image (letterbox top & bottom)', () {
      final converter = CoordinateConverter(
        imageWidth: 1000,
        imageHeight: 500,
        displayWidth: 500,
        displayHeight: 500,
      );

      expect(converter.scale, 0.5);
      expect(converter.renderedWidth, 500.0);
      expect(converter.renderedHeight, 250.0);
      expect(converter.offsetX, 0.0);
      expect(converter.offsetY, 125.0); // (500 - 250) / 2

      const imgBox = BoundingBox(left: 100, top: 100, width: 200, height: 100);
      final screenRect = converter.imageToScreenRect(imgBox);

      expect(screenRect.left, 50.0);
      expect(screenRect.top, 175.0); // 125 + (100 * 0.5)
      expect(screenRect.width, 100.0);
      expect(screenRect.height, 50.0);

      // Round-trip conversion
      final convertedBack = converter.screenToImageRect(screenRect);
      expect(convertedBack.left, closeTo(100.0, 0.001));
      expect(convertedBack.top, closeTo(100.0, 0.001));
      expect(convertedBack.width, closeTo(200.0, 0.001));
      expect(convertedBack.height, closeTo(100.0, 0.001));
    });

    test('Tall portrait image (pillarbox left & right)', () {
      final converter = CoordinateConverter(
        imageWidth: 500,
        imageHeight: 1000,
        displayWidth: 500,
        displayHeight: 500,
      );

      expect(converter.scale, 0.5);
      expect(converter.renderedWidth, 250.0);
      expect(converter.renderedHeight, 500.0);
      expect(converter.offsetX, 125.0); // (500 - 250) / 2
      expect(converter.offsetY, 0.0);

      const imgBox = BoundingBox(left: 50, top: 200, width: 100, height: 200);
      final screenRect = converter.imageToScreenRect(imgBox);

      expect(screenRect.left, 150.0); // 125 + (50 * 0.5)
      expect(screenRect.top, 100.0);
      expect(screenRect.width, 50.0);
      expect(screenRect.height, 100.0);

      final convertedBack = converter.screenToImageRect(screenRect);
      expect(convertedBack.left, closeTo(50.0, 0.001));
      expect(convertedBack.top, closeTo(200.0, 0.001));
      expect(convertedBack.width, closeTo(100.0, 0.001));
      expect(convertedBack.height, closeTo(200.0, 0.001));
    });

    test('Clamps screen coordinates outside rendered image rectangle', () {
      final converter = CoordinateConverter(
        imageWidth: 1000,
        imageHeight: 500,
        displayWidth: 500,
        displayHeight: 500,
      );

      // Tap way above the rendered image in top letterbox
      final clampedBox = converter.screenToImageRect(
        const Rect.fromLTWH(0, 0, 500, 50),
      );

      expect(clampedBox.top, 0.0);
      expect(clampedBox.height, 0.0);
    });
  });

  group('Review State & Toggle Logic Tests', () {
    test('Toggle findings between HIDE and KEEP updates action and score', () async {
      final mockLines = [
        const OcrLine(
          text: 'Contact: 9876543210',
          boundingBox: BoundingBox(left: 10, top: 20, width: 100, height: 30),
          elements: [
            OcrElement(
              text: 'Contact: 9876543210',
              boundingBox: BoundingBox(left: 10, top: 20, width: 100, height: 30),
            ),
          ],
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          ocrServiceProvider.overrideWithValue(
            MockOcrService(linesToReturn: mockLines),
          ),
        ],
      );

      container
          .read(selectedImageProvider.notifier)
          .setImage(XFile('test.png'));
      container
          .read(selectedPurposeProvider.notifier)
          .setPurpose(Purpose.paymentProof);

      // Await scan completion
      await container.read(scanFindingsProvider.future);

      final notifier = container.read(reviewNotifierProvider.notifier);
      final initialReview = container.read(reviewNotifierProvider);

      expect(initialReview.findings.length, 1);
      // In Payment Proof, phone number defaults to HIDE (redacted)
      expect(initialReview.findings.first.currentAction, RedactionAction.hide);

      // When redacted (hidden), residual exposure is 0
      final scoreHidden = container.read(liveExposureScoreProvider).totalScore;
      expect(scoreHidden, 0);

      // Toggle to KEEP (leaving personal phone exposed)
      notifier.toggleFinding(0);
      final afterKeep = container.read(reviewNotifierProvider);
      expect(afterKeep.findings.first.currentAction, RedactionAction.keep);

      // Kept sensitive item exposes data -> score increases
      final scoreKept = container.read(liveExposureScoreProvider).totalScore;
      expect(scoreKept, greaterThan(0));

      // Toggle back to HIDE (redacted) -> score drops back to 0
      notifier.toggleFinding(0);
      final afterHide = container.read(reviewNotifierProvider);
      expect(afterHide.findings.first.currentAction, RedactionAction.hide);
      expect(container.read(liveExposureScoreProvider).totalScore, 0);
    });
  });

  group('Manual Box Redaction Logic Tests', () {
    test('Adding, undoing, deleting manual boxes and verifying final redaction regions', () async {
      final container = ProviderContainer(
        overrides: [
          ocrServiceProvider.overrideWithValue(MockOcrService(linesToReturn: [])),
        ],
      );

      container.read(selectedImageProvider.notifier).setImage(XFile('test.png'));
      final notifier = container.read(reviewNotifierProvider.notifier);

      expect(container.read(reviewNotifierProvider).manualBoxes, isEmpty);

      // 1. Add two manual boxes
      const box1 = BoundingBox(left: 50, top: 50, width: 100, height: 40);
      const box2 = BoundingBox(left: 200, top: 300, width: 80, height: 60);

      notifier.addManualBox(box1);
      notifier.addManualBox(box2);

      final stateWithBoxes = container.read(reviewNotifierProvider);
      expect(stateWithBoxes.manualBoxes.length, 2);
      expect(stateWithBoxes.manualBoxes[0], box1);
      expect(stateWithBoxes.manualBoxes[1], box2);

      // Final redaction regions must include both manual boxes
      final regions = container.read(finalRedactionRegionsProvider);
      expect(regions.length, 2);
      expect(regions[0].source, RedactionSource.manual);
      expect(regions[0].rect, box1);
      expect(regions[1].rect, box2);

      // 2. Undo last box
      notifier.undoManualBox();
      expect(container.read(reviewNotifierProvider).manualBoxes.length, 1);
      expect(container.read(reviewNotifierProvider).manualBoxes.first, box1);

      // 3. Add box3, then delete box1
      const box3 = BoundingBox(left: 10, top: 10, width: 50, height: 50);
      notifier.addManualBox(box3);
      expect(container.read(reviewNotifierProvider).manualBoxes.length, 2);

      notifier.deleteManualBox(0); // Delete box1
      expect(container.read(reviewNotifierProvider).manualBoxes.length, 1);
      expect(container.read(reviewNotifierProvider).manualBoxes.first, box3);

      // 4. Clear all
      notifier.clearManualBoxes();
      expect(container.read(reviewNotifierProvider).manualBoxes, isEmpty);
      expect(container.read(finalRedactionRegionsProvider), isEmpty);
    });
  });
}
