import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overshare/core/app_state.dart';
import 'package:overshare/features/decision/purpose.dart';
import 'package:overshare/features/history/history_database.dart';
import 'package:overshare/features/history/history_providers.dart';
import 'package:overshare/features/history/history_screen.dart';
import 'package:overshare/features/history/models/finding_record.dart';
import 'package:overshare/features/history/models/scan_record.dart';
import 'package:overshare/features/redaction/export_service.dart';
import 'package:overshare/features/redaction/redaction_providers.dart';
import 'package:overshare/features/review/before_after_screen.dart';
import 'package:overshare/features/review/review_screen.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/finding.dart';
import 'package:overshare/features/scanner/models/sensitive_type.dart';
import 'package:overshare/features/scanner/scanner_providers.dart';

class MockPurposeNotifier extends SelectedPurposeNotifier {
  final SharingPurpose? initial;
  MockPurposeNotifier(this.initial);
  @override
  SharingPurpose? build() => initial;
}

class MockAudienceNotifier extends SelectedAudienceNotifier {
  final Audience initial;
  MockAudienceNotifier(this.initial);
  @override
  Audience build() => initial;
}

class MockSanitizedExportNotifier extends SanitizedExportNotifier {
  final SanitizedExportState initial;
  MockSanitizedExportNotifier(this.initial);
  @override
  SanitizedExportState build() => initial;
}

void main() {
  group('Phase 5 Differentiation & UI Polish Tests', () {
    testWidgets('ReviewScreen surfaces purpose/audience-aware reason and allows audience toggle', (tester) async {
      final findings = [
        Finding(
          type: SensitiveType.card,
          matchedText: '4111222233334444',
          maskedPreview: '•••• •••• •••• 4444',
          boundingBox: const BoundingBox(left: 10, top: 20, width: 100, height: 30),
          confidence: 0.99,
          source: FindingSource.rule,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scanFindingsProvider.overrideWith((ref) => findings),
            selectedPurposeProvider.overrideWith(() => MockPurposeNotifier(Purpose.paymentProof)),
            selectedAudienceProvider.overrideWith(() => MockAudienceNotifier(Audience.privateAudience)),
          ],
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Purpose & Audience Aware KEEP / HIDE with Reason
      expect(find.text('Payment Card Number'), findsOneWidget);
      expect(find.text('•••• •••• •••• 4444'), findsOneWidget);
      expect(find.text('HIDE'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Payment proof'), findsOneWidget);

      // Verify audience toggle button is present
      final audienceToggle = find.text('Private');
      expect(audienceToggle, findsOneWidget);
      await tester.tap(audienceToggle);
      await tester.pumpAndSettle();

      // Audience is switched to Public
      expect(find.text('Public'), findsOneWidget);
    });

    testWidgets('ReviewScreen opens Per-Finding Score Breakdown sheet on tapping score pill', (tester) async {
      final findings = [
        Finding(
          type: SensitiveType.card,
          matchedText: '4111222233334444',
          maskedPreview: '•••• •••• •••• 4444',
          boundingBox: const BoundingBox(left: 10, top: 20, width: 100, height: 30),
          confidence: 0.99,
          source: FindingSource.rule,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scanFindingsProvider.overrideWith((ref) => findings),
            selectedPurposeProvider.overrideWith(() => MockPurposeNotifier(Purpose.paymentProof)),
            selectedAudienceProvider.overrideWith(() => MockAudienceNotifier(Audience.privateAudience)),
          ],
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on score pill
      final scorePill = find.byIcon(Icons.info_outline_rounded).first;
      await tester.tap(scorePill);
      await tester.pumpAndSettle();

      // Verify Score Breakdown Sheet opened
      expect(find.text('Privacy Exposure Breakdown'), findsOneWidget);
      expect(
        find.textContaining('Exposure score reflects identifiable data exposed to the recipient'),
        findsOneWidget,
      );
      expect(find.text('Payment Card Number'), findsWidgets);
      expect(find.text('•••• •••• •••• 4444'), findsWidgets);
    });

    testWidgets('BeforeAfterScreen renders Post-Export Residual Exposure Report', (tester) async {
      final sanitizedState = SanitizedExportState(
        isProcessing: false,
        sanitizedBytes: Uint8List.fromList([0, 1, 2, 3]),
        exportResult: ExportResult(
          file: File('dummy_path.png'),
          fileName: 'overshare_test.png',
          byteSize: 4,
          formattedSize: '4 B',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedPurposeProvider.overrideWith(() => MockPurposeNotifier(Purpose.paymentProof)),
            sanitizedExportNotifierProvider.overrideWith(() => MockSanitizedExportNotifier(sanitizedState)),
          ],
          child: const MaterialApp(
            home: BeforeAfterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Post-Export Residual Exposure Report is surfaced
      expect(find.text('Post-Export Residual Exposure Report'), findsOneWidget);
      expect(find.text('Zero residual exposure verified (0/100)'), findsOneWidget);
      expect(find.text('Direct Pixel Buffer Overwrite'), findsOneWidget);
      expect(find.text('EXIF Metadata & GPS Purged'), findsOneWidget);
      expect(find.text('Kept Findings Audit'), findsOneWidget);
    });

    testWidgets('HistoryScreen surfaces Masked History Audit in list card and summary sheet', (tester) async {
      final repo = InMemoryHistoryRepository();
      final scanId = await repo.insertScan(
        scan: ScanRecord(
          createdAt: DateTime.now(),
          purpose: 'Customer Support',
          audience: 'Private Recipient',
          originalScore: 70,
          sanitizedScore: 0,
          status: 'completed',
          verificationStatus: 'verified',
        ),
        findings: [
          FindingRecord(
            scanId: 0,
            type: 'Email Address',
            maskedPreview: 's****@company.com',
            x: 10,
            y: 20,
            w: 100,
            h: 30,
            confidence: 0.95,
            recommendation: 'KEEP',
            reason: 'Legitimate contact handle',
            userAction: 'KEEP',
            source: 'ocr',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Masked History card element
      expect(find.text('Customer Support'), findsOneWidget);
      expect(find.text('Masked History Audit • Tap to view findings'), findsOneWidget);

      // Tap card to open summary sheet
      await tester.tap(find.text('Customer Support'));
      await tester.pumpAndSettle();

      // Verify Masked History summary sheet
      expect(find.text('Masked History Audit #$scanId'), findsOneWidget);
      expect(
        find.textContaining('Zero-Knowledge Log: Only masked previews'),
        findsOneWidget,
      );
      expect(find.text('s****@company.com'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('KEEP'), findsOneWidget);
    });
  });
}
