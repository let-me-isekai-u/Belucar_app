import 'package:intl/intl.dart';

final NumberFormat _walletAmountFormatter = NumberFormat('#,###', 'en_US');

String formatWalletAmount(num value, {bool showPlusForPositive = false}) {
  final roundedValue = value.round();
  final sign = roundedValue < 0
      ? '-'
      : (showPlusForPositive && roundedValue > 0 ? '+' : '');

  return '$sign${_walletAmountFormatter.format(roundedValue.abs())} đ';
}
