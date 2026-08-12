import 'package:intl/intl.dart';

abstract final class MoneyUtils {
  static double roundMoney(num value) => toCents(value) / 100;
  static int toCents(num value) => (value * 100).round();
  static double fromCents(int cents) => cents / 100;
  static bool moneyEquals(num first, num second) =>
      toCents(first) == toCents(second);

  static String formatCurrency(num value,
      {String currencyCode = 'MYR', bool compact = false}) {
    final symbol = currencyCode == 'MYR' ? 'RM' : currencyCode;
    final formatter = NumberFormat.currency(
      symbol: compact ? symbol : '$symbol ',
      decimalDigits: compact ? 0 : 2,
    );
    return formatter.format(value);
  }
}
