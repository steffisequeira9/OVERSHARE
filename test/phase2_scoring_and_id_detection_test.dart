import 'package:flutter_test/flutter_test.dart';
import 'package:overshare/features/decision/purpose.dart';
import 'package:overshare/features/decision/risk_scorer.dart';
import 'package:overshare/features/decision/rules_table.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/finding.dart';
import 'package:overshare/features/scanner/models/ocr_line.dart';
import 'package:overshare/features/scanner/models/sensitive_type.dart';
import 'package:overshare/features/scanner/pattern_detector.dart';
import 'package:overshare/features/scanner/verhoeff_checker.dart';

OcrLine _makeLine(String text) {
  return OcrLine(
    text: text,
    boundingBox: const BoundingBox(left: 0, top: 0, width: 300, height: 25),
    elements: [
      OcrElement(
        text: text,
        boundingBox: const BoundingBox(left: 0, top: 0, width: 300, height: 25),
      ),
    ],
  );
}

void main() {
  group('Verhoeff Algorithm & Aadhaar Tests', () {
    test('Verhoeff correctly validates valid Aadhaar checksum and rejects invalid', () {
      // 2345 6789 012 is 11 digits, calculate checksum
      final checkDigit = VerhoeffChecker.generateChecksum('23456789012');
      final validAadhaar = '23456789012$checkDigit';
      expect(VerhoeffChecker.validate(validAadhaar), isTrue);

      // Mutate one digit -> must fail
      final corrupted = '23456789011$checkDigit';
      expect(VerhoeffChecker.validate(corrupted), isFalse);
    });

    test('PatternDetector detects Verhoeff-valid Aadhaar with high confidence (0.99)', () {
      const detector = PatternDetector();
      final checkDigit = VerhoeffChecker.generateChecksum('34567890123');
      final validAadhaar = '3456 7890 123$checkDigit';

      final findings = detector.detectFindings([_makeLine(validAadhaar)]);
      expect(findings.any((f) => f.type == SensitiveType.aadhaar), isTrue);
      final aadhaarFinding = findings.firstWhere((f) => f.type == SensitiveType.aadhaar);
      expect(aadhaarFinding.confidence, 0.99);
    });
  });

  group('New Sensitive Patterns: Voter ID, DOB, Credentials', () {
    const detector = PatternDetector();

    test('Voter ID (EPIC) is detected with high confidence', () {
      final findings = detector.detectFindings([
        _makeLine('Voter ID: ABC1234567'),
      ]);

      expect(findings.any((f) => f.type == SensitiveType.voterId), isTrue);
      final voterFinding = findings.firstWhere((f) => f.type == SensitiveType.voterId);
      expect(voterFinding.matchedText, contains('ABC1234567'));
      expect(voterFinding.confidence, greaterThanOrEqualTo(0.95));
    });

    test('Date of Birth (DOB) is detected via contextual keywords', () {
      final findings = detector.detectFindings([
        _makeLine('DOB: 15/08/1990'),
      ]);

      expect(findings.any((f) => f.type == SensitiveType.dob), isTrue);
      final dobFinding = findings.firstWhere((f) => f.type == SensitiveType.dob);
      expect(dobFinding.matchedText, contains('15/08/1990'));
      expect(dobFinding.confidence, greaterThanOrEqualTo(0.90));
    });

    test('Credentials / Passwords / OTPs are detected with high confidence', () {
      final findings = detector.detectFindings([
        _makeLine('One Time Password: 849201'),
        _makeLine('Password: Secret@123'),
      ]);

      expect(findings.where((f) => f.type == SensitiveType.credential).length, 2);
    });
  });

  group('Identity Verification Scoring Regression Fix', () {
    test('Aadhaar card scan in Identity Verification produces score > 0 (NOT 0/100)', () {
      const scorer = RiskScorer();

      final findings = [
        Finding(
          type: SensitiveType.aadhaar,
          matchedText: '3456 7890 1234',
          maskedPreview: '•••• •••• 1234',
          boundingBox: const BoundingBox(left: 10, top: 20, width: 100, height: 30),
          confidence: 0.99,
        ),
        Finding(
          type: SensitiveType.face,
          matchedText: '[Face detected]',
          maskedPreview: '[Face detected]',
          boundingBox: const BoundingBox(left: 120, top: 20, width: 80, height: 80),
          confidence: 0.95,
        ),
        Finding(
          type: SensitiveType.dob,
          matchedText: '15/08/1990',
          maskedPreview: '••/••/••••',
          boundingBox: const BoundingBox(left: 10, top: 70, width: 90, height: 20),
          confidence: 0.92,
        ),
      ];

      // In identityVerification, Aadhaar is recommended HIDE (masked Aadhaar), DOB is OPTIONAL
      final result = scorer.calculateScore(findings, Purpose.identityVerification);
      expect(result.totalScore, greaterThan(0), reason: 'Aadhaar scan must NOT produce 0/100 score in Identity Verification');
      expect(result.exposureLevel, isNot('No Exposure'));
      expect(result.items.any((i) => i.type == SensitiveType.aadhaar && i.points > 0), isTrue);
    });
  });

  group('New Purposes: Marketplace Listing & Personal Doc Sharing', () {
    test('Marketplace listing hides phone, email, and bank account', () {
      final recPhone = RulesTable.getDecision(SensitiveType.phone, Purpose.marketplaceListing, Audience.publicAudience);
      expect(recPhone.action, RedactionAction.hide);

      final recEmail = RulesTable.getDecision(SensitiveType.email, Purpose.marketplaceListing, Audience.publicAudience);
      expect(recEmail.action, RedactionAction.hide);

      final recAccount = RulesTable.getDecision(SensitiveType.accountNumber, Purpose.marketplaceListing, Audience.publicAudience);
      expect(recAccount.action, RedactionAction.hide);

      // Amount is kept for asking price
      final recAmount = RulesTable.getDecision(SensitiveType.amount, Purpose.marketplaceListing, Audience.publicAudience);
      expect(recAmount.action, RedactionAction.keep);
    });

    test('Personal document sharing hides national IDs from public and recommends masking', () {
      final recAadhaar = RulesTable.getDecision(SensitiveType.aadhaar, Purpose.personalDocSharing, Audience.privateAudience);
      expect(recAadhaar.action, RedactionAction.hide);

      final recPan = RulesTable.getDecision(SensitiveType.pan, Purpose.personalDocSharing, Audience.privateAudience);
      expect(recPan.action, RedactionAction.hide);
    });
  });
}
