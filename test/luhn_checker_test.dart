import 'package:flutter_test/flutter_test.dart';
import 'package:overshare/features/scanner/luhn_checker.dart';

void main() {
  group('LuhnChecker Tests', () {
    test('Validates genuine credit/debit card numbers', () {
      // Standard valid test card numbers (Luhn compliant)
      expect(LuhnChecker.validate('4532 0150 0000 0007'), isTrue); // Visa 16
      expect(LuhnChecker.validate('5425-2334-3010-9903'), isTrue); // Mastercard 16
      expect(LuhnChecker.validate('378282246310005'), isTrue);     // Amex 15
      expect(LuhnChecker.validate('6011 1111 1111 1117'), isTrue); // Discover 16
    });

    test('Rejects invalid Luhn card numbers', () {
      expect(LuhnChecker.validate('4532 0150 0000 0008'), isFalse);
      expect(LuhnChecker.validate('5425-2334-3010-9904'), isFalse);
      expect(LuhnChecker.validate('378282246310006'), isFalse);
      expect(LuhnChecker.validate('9999 9999 9999 9999'), isFalse);
    });

    test('Rejects inputs with invalid lengths', () {
      expect(LuhnChecker.validate('12345'), isFalse);
      expect(LuhnChecker.validate('1234 5678 9012'), isFalse); // 12 digits
      expect(LuhnChecker.validate('123456789012345678901'), isFalse); // 21 digits
      expect(LuhnChecker.validate(''), isFalse);
    });
  });
}
