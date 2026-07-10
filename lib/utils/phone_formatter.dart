class PhoneFormatter {
  PhoneFormatter._();

  static String stripNonDigits(String input) =>
      input.replaceAll(RegExp(r'\D'), '');

  static String formatThai(String input) {
    final digits = stripNonDigits(input);
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static String storageValue(String formatted) => stripNonDigits(formatted);
}
