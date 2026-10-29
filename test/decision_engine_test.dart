import 'package:flutter_test/flutter_test.dart';
import 'package:overshare/features/decision/purpose.dart';
import 'package:overshare/features/decision/recommendation.dart';
import 'package:overshare/features/decision/risk_scorer.dart';
import 'package:overshare/features/decision/rules_table.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/finding.dart';
import 'package:overshare/features/scanner/models/sensitive_type.dart';

void main() {
  Finding makeFinding(SensitiveType type, String text, {double confidence = 1.0}) {
    return Finding(
      type: type,
      matchedText: text,
      boundingBox: const BoundingBox.zero(),
      confidence: confidence,
    );
  }

  group('Decision Engine - RulesTable Tests', () {
    test('Exhaustive matrix coverage: every (SensitiveType x Purpose x Audience) has valid decision', () {
      for (final purpose in Purpose.values) {
        for (final audience in Audience.values) {
          for (final type in SensitiveType.values) {
            final decision = RulesTable.getDecision(type, purpose, audience);
            expect(decision, isNotNull);
            expect(decision.action, isIn(RedactionAction.values));
            expect(decision.reason.isNotEmpty, isTrue);
          }
        }
      }
    });

    test('Consistency: No finding has action KEEP while reason states it exposes private data or must be hidden', () {
      final forbiddenKeepKeywords = [
        'exposes',
        'must remain',
        'must never',
        'confidential',
        'should not',
        'hide',
        'hidden',
        'identity theft',
        'leak',
      ];

      for (final purpose in Purpose.values) {
        for (final audience in Audience.values) {
          for (final type in SensitiveType.values) {
            final decision = RulesTable.getDecision(type, purpose, audience);
            if (decision.action == RedactionAction.keep) {
              final lowerReason = decision.reason.toLowerCase();
              for (final keyword in forbiddenKeepKeywords) {
                expect(
                  lowerReason.contains(keyword),
                  isFalse,
                  reason:
                      'Rule for ($type, $purpose, $audience) has action KEEP but its reason contains "$keyword": "${decision.reason}"',
                );
              }
            }
          }
        }
      }
    });

    test('Payment Proof purpose rules', () {
      final txnDecision = RulesTable.getDecision(SensitiveType.transactionId, Purpose.paymentProof);
      expect(txnDecision.action, RedactionAction.keep);

      final ifscDecision = RulesTable.getDecision(SensitiveType.ifsc, Purpose.paymentProof);
      expect(ifscDecision.action, RedactionAction.keep);

      final accDecision = RulesTable.getDecision(SensitiveType.accountNumber, Purpose.paymentProof);
      expect(accDecision.action, RedactionAction.hide);

      final phoneDecision = RulesTable.getDecision(SensitiveType.phone, Purpose.paymentProof);
      expect(phoneDecision.action, RedactionAction.hide);

      final cardDecision = RulesTable.getDecision(SensitiveType.card, Purpose.paymentProof);
      expect(cardDecision.action, RedactionAction.hide);

      final aadhaarDecision = RulesTable.getDecision(SensitiveType.aadhaar, Purpose.paymentProof);
      expect(aadhaarDecision.action, RedactionAction.hide);
    });

    test('Social Media purpose rules: hides almost everything', () {
      expect(RulesTable.getDecision(SensitiveType.card, Purpose.socialMedia).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.aadhaar, Purpose.socialMedia).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.pan, Purpose.socialMedia).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.phone, Purpose.socialMedia).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.email, Purpose.socialMedia).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.upiId, Purpose.socialMedia).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.transactionId, Purpose.socialMedia).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.accountNumber, Purpose.socialMedia).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.url, Purpose.socialMedia).action, RedactionAction.optional);
    });

    test('College Submission purpose rules', () {
      expect(RulesTable.getDecision(SensitiveType.email, Purpose.collegeSubmission).action, RedactionAction.keep);
      expect(RulesTable.getDecision(SensitiveType.transactionId, Purpose.collegeSubmission).action, RedactionAction.keep);
      expect(RulesTable.getDecision(SensitiveType.url, Purpose.collegeSubmission).action, RedactionAction.keep);
      expect(RulesTable.getDecision(SensitiveType.phone, Purpose.collegeSubmission).action, RedactionAction.optional);
      expect(RulesTable.getDecision(SensitiveType.card, Purpose.collegeSubmission).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.aadhaar, Purpose.collegeSubmission).action, RedactionAction.hide);
    });

    test('Customer Support purpose rules', () {
      expect(RulesTable.getDecision(SensitiveType.transactionId, Purpose.customerSupport).action, RedactionAction.keep);
      expect(RulesTable.getDecision(SensitiveType.email, Purpose.customerSupport).action, RedactionAction.keep);
      expect(RulesTable.getDecision(SensitiveType.url, Purpose.customerSupport).action, RedactionAction.keep);
      expect(RulesTable.getDecision(SensitiveType.phone, Purpose.customerSupport).action, RedactionAction.optional);
      expect(RulesTable.getDecision(SensitiveType.card, Purpose.customerSupport).action, RedactionAction.hide);
      expect(RulesTable.getDecision(SensitiveType.accountNumber, Purpose.customerSupport).action, RedactionAction.hide);
    });

    test('Audience changes decisions between private and public', () {
      // In payment proof: personName is optional for private recipient, but hidden for public sharing
      final privateDecision = RulesTable.getDecision(
        SensitiveType.personName,
        Purpose.paymentProof,
        Audience.privateAudience,
      );
      final publicDecision = RulesTable.getDecision(
        SensitiveType.personName,
        Purpose.paymentProof,
        Audience.publicAudience,
      );

      expect(privateDecision.action, RedactionAction.optional);
      expect(publicDecision.action, RedactionAction.hide);
    });

    test('Low-confidence findings (< 0.70) are automatically demoted to OPTIONAL', () {
      // Normal transactionId has confidence 0.95 -> KEEP
      final highConfFinding = makeFinding(SensitiveType.transactionId, 'UTR123456789', confidence: 0.95);
      final highRec = Recommendation.fromFinding(highConfFinding, Purpose.paymentProof);
      expect(highRec.action, RedactionAction.keep);

      // Low confidence transactionId (0.50) -> demoted to OPTIONAL with notice
      final lowConfFinding = makeFinding(SensitiveType.transactionId, 'UTR123456789', confidence: 0.50);
      final lowRec = Recommendation.fromFinding(lowConfFinding, Purpose.paymentProof);
      expect(lowRec.action, RedactionAction.optional);
      expect(lowRec.reason.contains('Low confidence detection; please check if sensitive'), isTrue);
    });
  });

  group('Decision Engine - RiskScorer Tests', () {
    const scorer = RiskScorer();

    test('Empty findings yields score 0 and empty items', () {
      final result = scorer.calculateScore([], Purpose.paymentProof);
      expect(result.totalScore, 0);
      expect(result.uncappedScore, 0);
      expect(result.items, isEmpty);
      expect(result.exposureLevel, 'No Exposure');
    });

    test('Findings marked KEEP contribute 0 points', () {
      final findings = [
        makeFinding(SensitiveType.transactionId, 'UTR32918840192'),
        makeFinding(SensitiveType.ifsc, 'SBIN0001234'),
      ];

      final result = scorer.calculateScore(findings, Purpose.paymentProof);
      expect(result.totalScore, 0);
      expect(result.uncappedScore, 0);
      expect(result.items.length, 2);
      expect(result.items.every((item) => item.points == 0), isTrue);
    });

    test('Breakdown item points sum exactly equals uncappedScore', () {
      final findings = [
        makeFinding(SensitiveType.card, '4532 0150 0000 0007'),
        makeFinding(SensitiveType.phone, '+91 98765 43210'),
        makeFinding(SensitiveType.url, 'https://example.com'),
      ];

      final result = scorer.calculateScore(findings, Purpose.paymentProof);
      final sumOfItems = result.items.fold<int>(0, (prev, item) => prev + item.points);

      expect(sumOfItems, result.uncappedScore);
      expect(result.totalScore, equals(result.uncappedScore));
      expect(result.items.length, 3);
    });

    test('Score cap: Score is strictly clamped to 100 when uncapped exceeds 100', () {
      final findings = [
        makeFinding(SensitiveType.card, '4532 0150 0000 0007'),
        makeFinding(SensitiveType.aadhaar, '2345 6789 0123'),
        makeFinding(SensitiveType.pan, 'ABCDE1234F'),
        makeFinding(SensitiveType.accountNumber, 'A/C: 123456789012'),
        makeFinding(SensitiveType.phone, '9876543210'),
        makeFinding(SensitiveType.email, 'test@example.com'),
        makeFinding(SensitiveType.upiId, 'test@okhdfcbank'),
      ];

      final result = scorer.calculateScore(findings, Purpose.socialMedia);

      expect(result.uncappedScore, greaterThan(100));
      expect(result.totalScore, 100);
      expect(result.exposureLevel, 'Critical Exposure');
    });

    test('Score changes dynamically when purpose is switched', () {
      final findings = [
        makeFinding(SensitiveType.transactionId, 'UTR32918840192'),
        makeFinding(SensitiveType.email, 'student@college.edu'),
      ];

      // In paymentProof: transactionId is KEEP (0 pts), email is HIDE (> 0 pts)
      final paymentResult = scorer.calculateScore(findings, Purpose.paymentProof);
      expect(paymentResult.items.firstWhere((i) => i.type == SensitiveType.transactionId).points, 0);
      expect(paymentResult.items.firstWhere((i) => i.type == SensitiveType.email).points, greaterThan(0));

      // In collegeSubmission: both transactionId and email are KEEP (both 0 pts)
      final collegeResult = scorer.calculateScore(findings, Purpose.collegeSubmission);
      expect(collegeResult.totalScore, 0);

      // In socialMedia: both are HIDE (both > 0 pts)
      final socialResult = scorer.calculateScore(findings, Purpose.socialMedia);
      expect(socialResult.totalScore, greaterThan(paymentResult.totalScore));
    });
  });
}
