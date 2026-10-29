class LuhnChecker {
  const LuhnChecker._();

  /// Validates a card number string using the standard Luhn (mod-10) algorithm.
  /// Ignores spaces, hyphens, and formatting characters.
  static bool validate(String rawNumber) {
    final digits = rawNumber.replaceAll(RegExp(r'\D'), '');

    // Standard payment cards range from 13 to 19 digits
    if (digits.length < 13 || digits.length > 19) {
      return false;
    }

    int sum = 0;
    bool alternate = false;

    for (int i = digits.length - 1; i >= 0; i--) {
      int digit = int.parse(digits[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }
}
