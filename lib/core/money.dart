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
  final normalized = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (normalized.isEmpty) {
    throw const FormatException('Số tiền không hợp lệ');
  }
  final value = int.parse(normalized);
  if (value <= 0) {
    throw const FormatException('Số tiền phải lớn hơn 0');
  }
  return value;
}
