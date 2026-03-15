import 'package:flutter/services.dart';

/// Formats Saudi phone numbers as: XX XXX XXXX
/// Input should be the local number without country code (e.g. 555566667).
class SaudiPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip all non-digit characters
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Limit to 9 digits (Saudi local number)
    final trimmed = digits.length > 9 ? digits.substring(0, 9) : digits;

    // Build formatted string: XX XXX XXXX
    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      if (i == 2 || i == 5) buffer.write(' ');
      buffer.write(trimmed[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
