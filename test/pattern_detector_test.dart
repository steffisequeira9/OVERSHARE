import 'package:flutter_test/flutter_test.dart';
import 'package:overshare/features/scanner/models/bounding_box.dart';
import 'package:overshare/features/scanner/models/ocr_line.dart';
import 'package:overshare/features/scanner/models/sensitive_type.dart';
import 'package:overshare/features/scanner/pattern_detector.dart';

void main() {
  const detector = PatternDetector();

  OcrLine makeLine(String text) {
    return OcrLine(
      text: text,
      boundingBox: const BoundingBox(left: 10, top: 20, width: 200, height: 30),
      elements: [
        OcrElement(
          text: text,
          boundingBox: const BoundingBox(left: 10, top: 20, width: 200, height: 30),
        ),
      ],
    );
  }

  group('PatternDetector - Email Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('Contact me at user.name@example.com.')]);
      expect(f1.any((f) => f.type == SensitiveType.email && f.matchedText == 'user.name@example.com'), isTrue);

      final f2 = detector.detectFindings([makeLine('Send info to alert_123@work-domain.co.in')]);
      expect(f2.any((f) => f.type == SensitiveType.email && f.matchedText == 'alert_123@work-domain.co.in'), isTrue);

      final f3 = detector.detectFindings([makeLine('Email: support+billing@service.org for help')]);
      expect(f3.any((f) => f.type == SensitiveType.email && f.matchedText == 'support+billing@service.org'), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('This is just normal text with no symbols')]);
      expect(f1.any((f) => f.type == SensitiveType.email), isFalse);

      final f2 = detector.detectFindings([makeLine('user@nodomain (missing tld)')]);
      expect(f2.any((f) => f.type == SensitiveType.email), isFalse);

      // UPI ID must NOT be reported as email
      final f3 = detector.detectFindings([makeLine('Paid to rahul@oksbi via UPI')]);
      expect(f3.any((f) => f.type == SensitiveType.email), isFalse);
    });
  });

  group('PatternDetector - UPI ID Tests (Generic, Sender, Recipient)', () {
    test('Generic UPI cases', () {
      final f1 = detector.detectFindings([makeLine('VPA: 9876543210@paytm')]);
      expect(f1.any((f) => f.type == SensitiveType.upiId && f.matchedText == '9876543210@paytm'), isTrue);

      final f2 = detector.detectFindings([makeLine('UPI ID: alice.smith@ybl')]);
      expect(f2.any((f) => f.type == SensitiveType.upiId && f.matchedText == 'alice.smith@ybl'), isTrue);
    });

    test('Sender vs Recipient UPI differentiation via cues', () {
      final fSender = detector.detectFindings([makeLine('From: rahul@oksbi debited')]);
      expect(fSender.any((f) => f.type == SensitiveType.senderUpiId && f.matchedText == 'rahul@oksbi'), isTrue);

      final fRecipient = detector.detectFindings([makeLine('Paid to: merchant@okhdfcbank')]);
      expect(fRecipient.any((f) => f.type == SensitiveType.recipientUpiId && f.matchedText == 'merchant@okhdfcbank'), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('My email is test@company.com')]);
      expect(f1.any((f) => f.type == SensitiveType.upiId || f.type == SensitiveType.recipientUpiId || f.type == SensitiveType.senderUpiId), isFalse);

      final f2 = detector.detectFindings([makeLine('No upi handle here @all')]);
      expect(f2.any((f) => f.type == SensitiveType.upiId), isFalse);
    });
  });

  group('PatternDetector - Phone Number Tests', () {
    test('3+ Positive cases (Indian + International)', () {
      final f1 = detector.detectFindings([makeLine('Call me at +91 98765 43210')]);
      expect(f1.any((f) => f.type == SensitiveType.phone), isTrue);

      final f2 = detector.detectFindings([makeLine('Mobile: 9876543210')]);
      expect(f2.any((f) => f.type == SensitiveType.phone && f.matchedText.contains('9876543210')), isTrue);

      final f3 = detector.detectFindings([makeLine('US Office: +1 (555) 123-4567')]);
      expect(f3.any((f) => f.type == SensitiveType.phone), isTrue);
    });

    test('2+ Negative cases (avoiding dates, currency, short codes)', () {
      final f1 = detector.detectFindings([makeLine('Transaction date: 2026-10-20')]);
      expect(f1.any((f) => f.type == SensitiveType.phone), isFalse);

      final f2 = detector.detectFindings([makeLine('Expiry: 12/26 or 20/10/2026')]);
      expect(f2.any((f) => f.type == SensitiveType.phone), isFalse);

      final f3 = detector.detectFindings([makeLine('Pincode 400076, OTP: 1234')]);
      expect(f3.any((f) => f.type == SensitiveType.phone), isFalse);
    });
  });

  group('PatternDetector - Web URL Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('Login at https://portal.university.edu/login')]);
      expect(f1.any((f) => f.type == SensitiveType.url), isTrue);

      final f2 = detector.detectFindings([makeLine('Check http://api.service.io/v1/user')]);
      expect(f2.any((f) => f.type == SensitiveType.url), isTrue);

      final f3 = detector.detectFindings([makeLine('Visit www.overshare-app.org/privacy')]);
      expect(f3.any((f) => f.type == SensitiveType.url), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('Just a regular sentence with no links.')]);
      expect(f1.any((f) => f.type == SensitiveType.url), isFalse);

      final f2 = detector.detectFindings([makeLine('version.1.2.3 released')]);
      expect(f2.any((f) => f.type == SensitiveType.url), isFalse);
    });
  });

  group('PatternDetector - Aadhaar Number Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('Aadhaar: 2345 6789 0123')]);
      expect(f1.any((f) => f.type == SensitiveType.aadhaar), isTrue);

      final f2 = detector.detectFindings([makeLine('UID: 9876-5432-1098')]);
      expect(f2.any((f) => f.type == SensitiveType.aadhaar), isTrue);

      final f3 = detector.detectFindings([makeLine('555566667777 verified')]);
      expect(f3.any((f) => f.type == SensitiveType.aadhaar), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('0123 4567 8901 is invalid')]);
      expect(f1.any((f) => f.type == SensitiveType.aadhaar), isFalse);

      final f2 = detector.detectFindings([makeLine('2345 6789 012 short')]);
      expect(f2.any((f) => f.type == SensitiveType.aadhaar), isFalse);
    });
  });

  group('PatternDetector - PAN Card Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('PAN: ABCDE1234F')]);
      expect(f1.any((f) => f.type == SensitiveType.pan && f.matchedText == 'ABCDE1234F'), isTrue);

      final f2 = detector.detectFindings([makeLine('Taxpayer AAAPL9876K on file')]);
      expect(f2.any((f) => f.type == SensitiveType.pan && f.matchedText == 'AAAPL9876K'), isTrue);

      final f3 = detector.detectFindings([makeLine('Permanent Acc: BKZPS0123M')]);
      expect(f3.any((f) => f.type == SensitiveType.pan && f.matchedText == 'BKZPS0123M'), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('ABCD12345F is invalid PAN')]);
      expect(f1.any((f) => f.type == SensitiveType.pan), isFalse);

      final f2 = detector.detectFindings([makeLine('abcde1234f should not match')]);
      expect(f2.any((f) => f.type == SensitiveType.pan), isFalse);
    });
  });

  group('PatternDetector - Payment Card (Luhn) Tests', () {
    test('3+ Positive cases (Luhn valid)', () {
      final f1 = detector.detectFindings([makeLine('Card: 4532 0150 0000 0007')]);
      expect(f1.any((f) => f.type == SensitiveType.card), isTrue);

      final f2 = detector.detectFindings([makeLine('Mastercard: 5425-2334-3010-9903')]);
      expect(f2.any((f) => f.type == SensitiveType.card), isTrue);

      final f3 = detector.detectFindings([makeLine('Amex: 3782 822463 10005')]);
      expect(f3.any((f) => f.type == SensitiveType.card), isTrue);
    });

    test('2+ Negative cases (Luhn invalid / wrong length)', () {
      final f1 = detector.detectFindings([makeLine('Card: 4532 0150 0000 0008')]);
      expect(f1.any((f) => f.type == SensitiveType.card), isFalse);

      final f2 = detector.detectFindings([makeLine('Fake: 9999 9999 9999 9999')]);
      expect(f2.any((f) => f.type == SensitiveType.card), isFalse);
    });
  });

  group('PatternDetector - IFSC Code Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('IFSC: SBIN0001234')]);
      expect(f1.any((f) => f.type == SensitiveType.ifsc && f.matchedText == 'SBIN0001234'), isTrue);

      final f2 = detector.detectFindings([makeLine('Branch Code HDFC0000456')]);
      expect(f2.any((f) => f.type == SensitiveType.ifsc && f.matchedText == 'HDFC0000456'), isTrue);

      final f3 = detector.detectFindings([makeLine('Routing ICIC0001890 confirmed')]);
      expect(f3.any((f) => f.type == SensitiveType.ifsc && f.matchedText == 'ICIC0001890'), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('SBIN1001234 invalid IFSC')]);
      expect(f1.any((f) => f.type == SensitiveType.ifsc), isFalse);

      final f2 = detector.detectFindings([makeLine('SBI0001234 too short')]);
      expect(f2.any((f) => f.type == SensitiveType.ifsc), isFalse);
    });
  });

  group('PatternDetector - Bank Account Number Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('A/C No: 123456789012')]);
      expect(f1.any((f) => f.type == SensitiveType.accountNumber), isTrue);

      final f2 = detector.detectFindings([makeLine('Account: 987654321098')]);
      expect(f2.any((f) => f.type == SensitiveType.accountNumber), isTrue);

      final f3 = detector.detectFindings([makeLine('Acc No. 00012345678901')]);
      expect(f3.any((f) => f.type == SensitiveType.accountNumber), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('A/C 1234 (too short)')]);
      expect(f1.any((f) => f.type == SensitiveType.accountNumber), isFalse);

      final f2 = detector.detectFindings([makeLine('Total items: 5000')]);
      expect(f2.any((f) => f.type == SensitiveType.accountNumber), isFalse);
    });
  });

  group('PatternDetector - Transaction / UTR ID Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('UTR32918840192 verified')]);
      expect(f1.any((f) => f.type == SensitiveType.transactionId), isTrue);

      final f2 = detector.detectFindings([makeLine('Txn ID: TXN9876543210')]);
      expect(f2.any((f) => f.type == SensitiveType.transactionId), isTrue);

      final f3 = detector.detectFindings([makeLine('UPI Ref No: 429104829103')]);
      expect(f3.any((f) => f.type == SensitiveType.transactionId), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('Standard text without transaction numbers')]);
      expect(f1.any((f) => f.type == SensitiveType.transactionId), isFalse);

      final f2 = detector.detectFindings([makeLine('Txn: 12')]);
      expect(f2.any((f) => f.type == SensitiveType.transactionId), isFalse);
    });
  });

  group('PatternDetector - Amount Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('Paid ₹1,500.00 for groceries')]);
      expect(f1.any((f) => f.type == SensitiveType.amount && f.matchedText.contains('1,500')), isTrue);

      final f2 = detector.detectFindings([makeLine('Total: Rs. 450 debited')]);
      expect(f2.any((f) => f.type == SensitiveType.amount && f.matchedText.contains('450')), isTrue);

      final f3 = detector.detectFindings([makeLine('Transferred INR 25000 successfully')]);
      expect(f3.any((f) => f.type == SensitiveType.amount && f.matchedText.contains('25000')), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('No currency value here 100')]);
      expect(f1.any((f) => f.type == SensitiveType.amount), isFalse);

      final f2 = detector.detectFindings([makeLine('Just text without numbers')]);
      expect(f2.any((f) => f.type == SensitiveType.amount), isFalse);
    });
  });

  group('PatternDetector - Date / Time Tests', () {
    test('3+ Positive cases', () {
      final f1 = detector.detectFindings([makeLine('Dated 24/10/2026')]);
      expect(f1.any((f) => f.type == SensitiveType.dateTime && f.matchedText.contains('24/10/2026')), isTrue);

      final f2 = detector.detectFindings([makeLine('Event on 15 Aug 2026')]);
      expect(f2.any((f) => f.type == SensitiveType.dateTime && f.matchedText.contains('15 Aug 2026')), isTrue);

      final f3 = detector.detectFindings([makeLine('Time: 10:45 PM')]);
      expect(f3.any((f) => f.type == SensitiveType.dateTime && f.matchedText.contains('10:45 PM')), isTrue);
    });

    test('2+ Negative cases', () {
      final f1 = detector.detectFindings([makeLine('Version 1.2.3 was deployed')]);
      expect(f1.any((f) => f.type == SensitiveType.dateTime), isFalse);

      final f2 = detector.detectFindings([makeLine('Scores were 10 to 5')]);
      expect(f2.any((f) => f.type == SensitiveType.dateTime), isFalse);
    });
  });

  group('PatternDetector - Person Name via Label Proximity Tests', () {
    test('3+ Positive cases with label cues and low confidence (0.45)', () {
      final f1 = detector.detectFindings([makeLine('Paid to: Rohan Sharma')]);
      expect(f1.any((f) => f.type == SensitiveType.personName && f.matchedText == 'Rohan Sharma' && f.confidence < 0.70), isTrue);

      final f2 = detector.detectFindings([makeLine('From: Priya Patel')]);
      expect(f2.any((f) => f.type == SensitiveType.personName && f.matchedText == 'Priya Patel'), isTrue);

      final f3 = detector.detectFindings([makeLine('Name: John Michael Doe')]);
      expect(f3.any((f) => f.type == SensitiveType.personName && f.matchedText == 'John Michael Doe'), isTrue);
    });

    test('2+ Negative cases (no label, or non-name organization keywords)', () {
      // No label proximity
      final f1 = detector.detectFindings([makeLine('Rohan Sharma was walking in the park')]);
      expect(f1.any((f) => f.type == SensitiveType.personName), isFalse);

      // Organization keyword rejection
      final f2 = detector.detectFindings([makeLine('Paid to: State Bank Of India')]);
      expect(f2.any((f) => f.type == SensitiveType.personName), isFalse);
    });
  });

  group('PatternDetector - Bounding Box Substring Mapping', () {
    test('Calculates bounding box proportionally for substrings within an element', () {
      const line = OcrLine(
        text: 'Sent to user@test.com today',
        boundingBox: BoundingBox(left: 0, top: 10, width: 270, height: 20),
        elements: [
          OcrElement(
            text: 'Sent to user@test.com today',
            boundingBox: BoundingBox(left: 0, top: 10, width: 270, height: 20),
          ),
        ],
      );

      final findings = detector.detectFindings([line]);
      expect(findings.length, 1);
      final emailFinding = findings.first;
      expect(emailFinding.type, SensitiveType.email);
      expect(emailFinding.matchedText, 'user@test.com');

      expect(emailFinding.boundingBox.left, greaterThan(0));
      expect(emailFinding.boundingBox.width, greaterThan(50));
      expect(emailFinding.boundingBox.height, equals(20));
    });
  });
}
