import 'package:intl/intl.dart';

class Money {
  const Money(this.amount);

  final int amount;

  static final NumberFormat _vndFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  String formatVnd() => _vndFormat.format(amount);

  Money operator +(Money other) => Money(amount + other.amount);
  Money operator -(Money other) => Money(amount - other.amount);
}

int parseVndAmount(String input) {
  if (RegExp(r'[\-‐-―−]').hasMatch(input)) {
    throw const FormatException('amountPositive');
  }
  if (RegExp(r'[^0-9\s.,₫]').hasMatch(input)) {
    throw const FormatException('amountInvalid');
  }
  final normalized = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    throw const FormatException('amountInvalid');
  }
  final value = int.parse(normalized);
  if (value <= 0) {
    throw const FormatException('amountPositive');
  }
  return value;
}
