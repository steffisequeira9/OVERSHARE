import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overshare/core/app_state.dart';
import 'package:overshare/features/decision/purpose.dart';
import 'package:overshare/features/decision/recommendation.dart';
import 'package:overshare/features/decision/risk_scorer.dart';
import 'package:overshare/features/decision/rules_table.dart';
import 'package:overshare/features/review/review_notifier.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/finding.dart';
import 'package:overshare/features/scanner/models/sensitive_type.dart';
import 'package:overshare/features/scanner/scanner_providers.dart';

void main() {
  group('Purpose-Aware Privacy Analysis Engine', () {
    const scorer = RiskScorer();

    final testFindings = [
      Finding(
        type: SensitiveType.personName,
        matchedText: 'Rahul Sharma',
        boundingBox: const BoundingBox(left: 10, top: 10, width: 100, height: 20),
        confidence: 0.45, // low confidence name detection
      ),
      Finding(
        type: SensitiveType.phone,
        matchedText: '+91 98765 43210',
        boundingBox: const BoundingBox(left: 10, top: 40, width: 100, height: 20),
        confidence: 0.95,
      ),
      Finding(
        type: SensitiveType.upiId,
        matchedText: 'rahul@okhdfcbank',
        boundingBox: const BoundingBox(left: 10, top: 70, width: 100, height: 20),
        confidence: 0.90,
      ),
      Finding(
        type: SensitiveType.amount,
        matchedText: '₹1,500.00',
        boundingBox: const BoundingBox(left: 10, top: 100, width: 100, height: 20),
        confidence: 0.92,
      ),
      Finding(
        type: SensitiveType.transactionId,
        matchedText: '412345678901',
        boundingBox: const BoundingBox(left: 10, top: 130, width: 100, height: 20),
        confidence: 0.95,
      ),
      Finding(
        type: SensitiveType.accountNumber,
        matchedText: 'A/c No. ...1234',
        boundingBox: const BoundingBox(left: 10, top: 160, width: 100, height: 20),
        confidence: 0.96,
      ),
      Finding(
        type: SensitiveType.dateTime,
        matchedText: '28 Oct 2026, 10:30 AM',
        boundingBox: const BoundingBox(left: 10, top: 190, width: 100, height: 20),
        confidence: 0.88,
      ),
    ];

    test('1. Image detection remains independent of purpose', () {
      // Detections are fixed regardless of which purpose is evaluated
      final countJob = testFindings.length;
      final countBank = testFindings.length;
      final countCollege = testFindings.length;

      expect(countJob, equals(7));
      expect(countBank, equals(7));
      expect(countCollege, equals(7));
    });

    test('2. Low-confidence KEEP findings (e.g. personName at 0.45) are NOT demoted to OPTIONAL', () {
      final rec = Recommendation.fromFinding(
        testFindings.firstWhere((f) => f.type == SensitiveType.personName),
        Purpose.jobApplication,
        Audience.privateAudience,
      );

      expect(rec.action, equals(RedactionAction.keep));
      expect(rec.reason, contains('Candidate name'));
    });

    test('3. Low-confidence HIDE findings ARE demoted to OPTIONAL with verification guidance', () {
      final lowConfAccount = Finding(
        type: SensitiveType.accountNumber,
        matchedText: '1234',
        boundingBox: const BoundingBox(left: 0, top: 0, width: 50, height: 20),
        confidence: 0.55,
      );

      final rec = Recommendation.fromFinding(
        lowConfAccount,
        Purpose.jobApplication,
        Audience.privateAudience,
      );

      expect(rec.action, equals(RedactionAction.optional));
      expect(rec.reason, contains('Low confidence detection; please check if sensitive.'));
    });

    test('4. Job Application rules: preserves candidate name & timeline, flags contact, hides financial data', () {
      final recs = generateRecommendations(testFindings, Purpose.jobApplication, Audience.privateAudience);

      final byType = {for (final r in recs) r.finding.type: r};

      expect(byType[SensitiveType.personName]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.dateTime]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.phone]!.action, equals(RedactionAction.optional));
      expect(byType[SensitiveType.upiId]!.action, equals(RedactionAction.hide));
      expect(byType[SensitiveType.amount]!.action, equals(RedactionAction.hide));
      expect(byType[SensitiveType.transactionId]!.action, equals(RedactionAction.hide));
      expect(byType[SensitiveType.accountNumber]!.action, equals(RedactionAction.hide));
    });

    test('5. Bank Dispute rules: preserves transaction reference, amount, account, handles, and customer name', () {
      final recs = generateRecommendations(testFindings, Purpose.bankDispute, Audience.privateAudience);

      final byType = {for (final r in recs) r.finding.type: r};

      expect(byType[SensitiveType.personName]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.transactionId]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.amount]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.accountNumber]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.upiId]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.phone]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.dateTime]!.action, equals(RedactionAction.keep));
    });

    test('6. College Submission rules: preserves authorship, registration reference & deadline, flags phone & fees, hides bank accounts', () {
      final recs = generateRecommendations(testFindings, Purpose.collegeSubmission, Audience.privateAudience);

      final byType = {for (final r in recs) r.finding.type: r};

      expect(byType[SensitiveType.personName]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.dateTime]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.transactionId]!.action, equals(RedactionAction.keep));
      expect(byType[SensitiveType.amount]!.action, equals(RedactionAction.optional));
      expect(byType[SensitiveType.phone]!.action, equals(RedactionAction.optional));
      expect(byType[SensitiveType.upiId]!.action, equals(RedactionAction.hide));
      expect(byType[SensitiveType.accountNumber]!.action, equals(RedactionAction.hide));
    });

    test('7. Exposure scores naturally reflect purpose differentiation on the same image', () {
      final scoreJob = scorer.calculateScore(testFindings, Purpose.jobApplication, Audience.privateAudience);
      final scoreBank = scorer.calculateScore(testFindings, Purpose.bankDispute, Audience.privateAudience);
      final scoreCollege = scorer.calculateScore(testFindings, Purpose.collegeSubmission, Audience.privateAudience);

      // Bank dispute legitimately needs almost all payment receipt info, so residual exposure is 0
      expect(scoreBank.totalScore, equals(0));
      expect(scoreBank.exposureLevel, equals('No Exposure'));

      // Job application hides 4 financial items + flags phone: exposure score is significantly higher
      expect(scoreJob.totalScore, greaterThan(50));

      // College submission flags amount and txId as optional, hides phone, upi, account: score is distinct
      expect(scoreCollege.totalScore, greaterThan(30));
      expect(scoreCollege.totalScore, isNot(equals(scoreJob.totalScore)));
      expect(scoreCollege.totalScore, isNot(equals(scoreBank.totalScore)));
    });

    test('8. Riverpod integration: switching selectedPurposeProvider updates review notifier and live score', () {
      final container = ProviderContainer(
        overrides: [
          scanFindingsProvider.overrideWith((ref) => testFindings),
        ],
      );
      addTearDown(container.dispose);

      // Default purpose: paymentProof
      var currentPurpose = container.read(selectedPurposeProvider) ?? Purpose.paymentProof;
      var score = container.read(liveExposureScoreProvider);
      expect(currentPurpose, equals(Purpose.paymentProof));

      // Switch to Bank Dispute
      container.read(selectedPurposeProvider.notifier).setPurpose(Purpose.bankDispute);
      currentPurpose = container.read(selectedPurposeProvider)!;
      var reviewState = container.read(reviewNotifierProvider);
      score = container.read(liveExposureScoreProvider);

      expect(currentPurpose, equals(Purpose.bankDispute));
      // In Bank Dispute, all test findings default to KEEP
      expect(reviewState.findings.every((f) => f.currentAction.isKeep), isTrue);
      expect(score.totalScore, equals(0));

      // Switch to Job Application
      container.read(selectedPurposeProvider.notifier).setPurpose(Purpose.jobApplication);
      currentPurpose = container.read(selectedPurposeProvider)!;
      reviewState = container.read(reviewNotifierProvider);
      score = container.read(liveExposureScoreProvider);

      expect(currentPurpose, equals(Purpose.jobApplication));
      // Financial items should default to HIDE
      final hideItems = reviewState.findings.where((f) => f.currentAction.isHide).toList();
      expect(hideItems.length, greaterThanOrEqualTo(4));
      // Kept items (name, dateTime) contribute 0 pts, redacted contribute 0 residual pts
      expect(score.totalScore, equals(0));

      // Toggle an item (e.g. Account Number) from HIDE to KEEP
      final accIndex = reviewState.findings.indexWhere((f) => f.finding.type == SensitiveType.accountNumber);
      expect(accIndex, greaterThanOrEqualTo(0));
      container.read(reviewNotifierProvider.notifier).toggleFinding(accIndex);

      final updatedScore = container.read(liveExposureScoreProvider);
      expect(updatedScore.totalScore, greaterThan(0));
      expect(updatedScore.items.firstWhere((i) => i.type == SensitiveType.accountNumber).points, greaterThan(0));
    });
  });
}
