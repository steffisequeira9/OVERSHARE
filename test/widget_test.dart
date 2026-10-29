import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:overshare/core/app_state.dart';
import 'package:overshare/features/decision/purpose.dart';
import 'package:overshare/features/decision/purpose_screen.dart';
import 'package:overshare/features/import/preview_screen.dart';
import 'package:overshare/features/redaction/redaction_providers.dart';
import 'package:overshare/features/review/review_screen.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/ocr_line.dart';
import 'package:overshare/features/scanner/ocr_service.dart';
import 'package:overshare/features/scanner/scanner_providers.dart';
import 'package:overshare/main.dart';

void main() {
  group('Stage 6 UI & Redaction Integration Tests', () {
    testWidgets('Home screen renders branding and import button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: OvershareApp(),
        ),
      );

      expect(find.text('OVERSHARE'), findsOneWidget);
      expect(
        find.text('Before You Share It, Know What It Reveals.'),
        findsOneWidget,
      );
      expect(find.text('Import image'), findsOneWidget);
      expect(find.text('100% On-Device Privacy'), findsOneWidget);
    });

    testWidgets('Image preview screen displays image info and continue button', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();
      container
          .read(selectedImageProvider.notifier)
          .setImage(XFile('test_screenshot.png'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ImagePreviewScreen(),
          ),
        ),
      );

      expect(find.text('Image Preview'), findsOneWidget);
      expect(find.text('test_screenshot.png'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Purpose selector screen selects purpose and navigates', (
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PurposeSelectorScreen(),
          ),
        ),
      );

      expect(find.text('Payment proof'), findsOneWidget);

      await tester.tap(find.text('Payment proof'));
      await tester.pumpAndSettle();

      expect(container.read(selectedPurposeProvider), Purpose.paymentProof);

      await tester.tap(find.text('Continue to Analysis'));
      await tester.pumpAndSettle();

      expect(find.text('Analysis Results'), findsOneWidget);
    });

    testWidgets('Review screen navigates to SafeCopyScreen with style choice and EXIF check', (
      WidgetTester tester,
    ) async {
      final mockLines = [
        const OcrLine(
          text: 'Payment to 9876543210@paytm',
          boundingBox: BoundingBox(left: 10, top: 20, width: 300, height: 25),
          elements: [
            OcrElement(
              text: 'Payment to 9876543210@paytm',
              boundingBox: BoundingBox(left: 10, top: 20, width: 300, height: 25),
            ),
          ],
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          ocrServiceProvider.overrideWithValue(
            MockOcrService(linesToReturn: mockLines),
          ),
          originalMetadataProvider.overrideWith((ref) => Future.value([])),
        ],
      );

      container
          .read(selectedImageProvider.notifier)
          .setImage(XFile('test_screenshot.png'));
      container
          .read(selectedPurposeProvider.notifier)
          .setPurpose(Purpose.paymentProof);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Review & Redact'), findsOneWidget);
      expect(find.textContaining('Create safe copy'), findsOneWidget);

      // Tap "Create safe copy" to navigate to SafeCopyScreen
      await tester.tap(find.textContaining('Create safe copy'));
      await tester.pumpAndSettle();

      expect(find.text('Export Safe Copy'), findsOneWidget);
      expect(find.text('Solid Black Fill'), findsOneWidget);
      expect(find.text('Heavy Pixelation'), findsOneWidget);
      expect(find.text('Metadata Clean Check'), findsOneWidget);
      expect(find.text('EXIF & Hardware Metadata Removal'), findsOneWidget);
      expect(find.text('Generate & Export Safe Copy'), findsOneWidget);
    });
  });
}
