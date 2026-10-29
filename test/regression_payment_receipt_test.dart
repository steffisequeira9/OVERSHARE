import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:overshare/core/app_state.dart';
import 'package:overshare/core/purpose.dart';
import 'package:overshare/features/decision/decision_providers.dart';
import 'package:overshare/features/review/results_screen.dart';
import 'package:overshare/features/scanner/face_detector_service.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/finding.dart';
import 'package:overshare/features/scanner/models/ocr_line.dart';
import 'package:overshare/features/scanner/models/sensitive_type.dart';
import 'package:overshare/features/scanner/ocr_service.dart';
import 'package:overshare/features/scanner/pattern_detector.dart';
import 'package:overshare/features/scanner/scanner_providers.dart';

void main() {
  const detector = PatternDetector();

  OcrLine makeLine(String text, {double top = 10, double left = 10, double width = 200, double height = 25}) {
    return OcrLine(
      text: text,
      boundingBox: BoundingBox(left: left, top: top, width: width, height: height),
      elements: [
        OcrElement(
          text: text,
          boundingBox: BoundingBox(left: left, top: top, width: width, height: height),
        ),
      ],
    );
  }

  group('Payment Receipt Detection Regression Tests', () {
    test('Google Pay receipt detects UPI ID, phone, transaction IDs, amount, and person name', () {
      final lines = [
        makeLine('Google Pay'),
        makeLine('Paid to: Rahul Sharma'),
        makeLine('+91 98765 43210'),
        makeLine('rahul.sharma@okhdfcbank'),
        makeLine('₹1,500.00'),
        makeLine('Completed • 28 Oct 2026, 10:30 AM'),
        makeLine('UPI transaction ID: 412345678901'),
        makeLine('Google transaction ID: CICAgKDs_8i-Cg'),
        makeLine('From: State Bank of India'),
        makeLine('A/c No. ...1234'),
      ];

      final findings = detector.detectFindings(lines);

      expect(findings, isNotEmpty, reason: 'Payment receipt MUST produce findings');

      // 1. Phone number
      final hasPhone = findings.any((f) => f.type == SensitiveType.phone);
      expect(hasPhone, isTrue, reason: 'Phone number +91 98765 43210 must be detected');

      // 2. UPI ID
      final hasUpi = findings.any(
        (f) => (f.type == SensitiveType.upiId || f.type == SensitiveType.recipientUpiId) &&
            f.matchedText.contains('rahul.sharma@okhdfcbank'),
      );
      expect(hasUpi, isTrue, reason: 'UPI ID rahul.sharma@okhdfcbank must be detected');

      // 3. UPI Transaction ID & Google Transaction ID
      final txnFindings = findings.where((f) => f.type == SensitiveType.transactionId).toList();
      expect(txnFindings.length, greaterThanOrEqualTo(2), reason: 'Both UPI and Google transaction IDs must be detected');

      // 4. Amount
      final hasAmount = findings.any((f) => f.type == SensitiveType.amount);
      expect(hasAmount, isTrue, reason: 'Payment amount must be detected');

      // 5. Account reference
      final hasAccount = findings.any((f) => f.type == SensitiveType.accountNumber);
      expect(hasAccount, isTrue, reason: 'Masked account reference A/c No. ...1234 must be detected');

      // 6. Person name
      final hasName = findings.any((f) => f.type == SensitiveType.personName);
      expect(hasName, isTrue, reason: 'Person name Rahul Sharma via Paid to must be detected');
    });

    test('PhonePe receipt detects UTR, Txn. ID with dot, Ref No. with dot, and UPI ID', () {
      final lines = [
        makeLine('Transaction Successful'),
        makeLine('Paid to: Priya Verma'),
        makeLine('priya@ybl'),
        makeLine('+919876543210'),
        makeLine('₹850'),
        makeLine('Debited from: State Bank of India'),
        makeLine('UTR: 329188401920'),
        makeLine('Txn. ID: T241028123456789'),
        makeLine('Ref No. 123456789012'),
      ];

      final findings = detector.detectFindings(lines);

      expect(findings, isNotEmpty);
      expect(findings.any((f) => f.type == SensitiveType.recipientUpiId || f.type == SensitiveType.upiId), isTrue);
      expect(findings.any((f) => f.type == SensitiveType.phone), isTrue);

      // Verify all transaction IDs including those with dots in Txn. ID and Ref No.
      final txns = findings.where((f) => f.type == SensitiveType.transactionId).toList();
      expect(txns.length, greaterThanOrEqualTo(3), reason: 'UTR, Txn. ID: ..., and Ref No. ... must all be matched');
    });

    test('Paytm receipt with Order ID, UPI Ref No., numeric UPI, and masked account', () {
      final lines = [
        makeLine('Payment to Merchant Store'),
        makeLine('Paid to: 9876543210@paytm'),
        makeLine('Mobile Number: 9876543210'),
        makeLine('Order ID: ORDER_987654321'),
        makeLine('UPI Ref No. 429810293847'),
        makeLine('₹ 2,400.00'),
        makeLine('A/c: 123456789012'),
      ];

      final findings = detector.detectFindings(lines);

      expect(findings.any((f) => f.type == SensitiveType.upiId || f.type == SensitiveType.recipientUpiId), isTrue);
      expect(findings.any((f) => f.type == SensitiveType.phone), isTrue);
      expect(findings.where((f) => f.type == SensitiveType.transactionId).length, greaterThanOrEqualTo(2));
      expect(findings.any((f) => f.type == SensitiveType.amount), isTrue);
      expect(findings.any((f) => f.type == SensitiveType.accountNumber), isTrue);
    });

    test('Multi-line payment receipt labels (label on line N, value on line N+1)', () {
      final lines = [
        makeLine('Google Pay'),
        makeLine('Paid to'),
        makeLine('Amitabh Bachchan'),
        makeLine('UPI ID'),
        makeLine('amitabh@oksbi'),
        makeLine('UPI transaction ID'),
        makeLine('430192849102'),
        makeLine('Amount'),
        makeLine('1500.00'),
      ];

      final findings = detector.detectFindings(lines);

      expect(findings.any((f) => f.type == SensitiveType.personName), isTrue,
          reason: 'Person name on line after Paid to must be detected');
      expect(findings.any((f) => f.type == SensitiveType.upiId), isTrue,
          reason: 'UPI ID on line after UPI ID label must be detected');
      expect(findings.any((f) => f.type == SensitiveType.transactionId), isTrue,
          reason: 'Transaction ID on line after UPI transaction ID label must be detected');
      expect(findings.any((f) => f.type == SensitiveType.amount), isTrue,
          reason: 'Amount on line after Amount label must be detected');
    });

    test('Exposure score and recommendations are NOT zero on payment receipts', () async {
      final container = ProviderContainer(
        overrides: [
          ocrServiceProvider.overrideWithValue(
            MockOcrService(
              linesToReturn: [
                makeLine('Paid to: Suresh Raina'),
                makeLine('suresh@okaxis'),
                makeLine('Mobile: +91 98765 43210'),
                makeLine('Txn ID: 9482948201'),
                makeLine('₹5,000.00'),
                makeLine('A/c No. ...9876'),
              ],
            ),
          ),
          faceDetectorServiceProvider.overrideWithValue(
            MockFaceDetectorService(facesToReturn: []),
          ),
        ],
      );

      container.read(selectedImageProvider.notifier).setImage(XFile('fictional_receipt.png'));
      container.read(selectedPurposeProvider.notifier).setPurpose(Purpose.paymentProof);

      final findings = await container.read(scanFindingsProvider.future);
      expect(findings, isNotEmpty);

      final recs = container.read(recommendationsProvider);
      expect(recs, isNotEmpty, reason: 'Zero recommendations regression must not occur');

      final score = container.read(riskScoreResultProvider);
      expect(score.totalScore, greaterThan(0), reason: 'Exposure score must NOT be 0/100 on sensitive receipt');
      expect(score.items, isNotEmpty);
    });
  });

  group('OCR Failure & Error Reporting Regression Tests', () {
    testWidgets('OCR failure throws OcrException and produces AsyncError, NEVER empty findings with 0 score',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          ocrServiceProvider.overrideWithValue(
            MockOcrService(
              shouldThrow: true,
              errorMessage: 'Camera OCR model download failed on-device',
            ),
          ),
          faceDetectorServiceProvider.overrideWithValue(
            MockFaceDetectorService(facesToReturn: []),
          ),
        ],
      );

      container.read(selectedImageProvider.notifier).setImage(XFile('test_receipt.png'));

      AsyncValue<List<Finding>>? capturedState;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              capturedState = ref.watch(scanFindingsProvider);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pump();

      expect(capturedState, isNotNull);
      expect(capturedState!.hasError, isTrue, reason: 'OCR failure must result in an error state');
      expect(capturedState!.error.toString(), contains('Camera OCR model download failed'));

      // Recommendations must be empty in orElse, but risk score is NOT falsely presented as verified 0
      final recs = container.read(recommendationsProvider);
      expect(recs, isEmpty);

      container.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ResultsScreen displays Detection Incomplete and manual redaction button on OCR failure',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          ocrServiceProvider.overrideWithValue(
            MockOcrService(
              shouldThrow: true,
              errorMessage: 'Simulated OCR initialization failure',
            ),
          ),
          faceDetectorServiceProvider.overrideWithValue(
            MockFaceDetectorService(facesToReturn: []),
          ),
        ],
      );

      container.read(selectedImageProvider.notifier).setImage(XFile('receipt.png'));
      container.read(selectedPurposeProvider.notifier).setPurpose(Purpose.paymentProof);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ResultsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Detection Incomplete UI is shown
      expect(find.text('Detection Incomplete'), findsOneWidget);
      expect(find.text('Retry Scan'), findsOneWidget);
      expect(find.text('Continue to Manual Redaction'), findsOneWidget);

      // Verify "No Sensitive Patterns Found" is NOT falsely shown
      expect(find.text('No Sensitive Patterns Found'), findsNothing);
      expect(find.text('Privacy Exposure Score'), findsNothing);
    });
  });
}
