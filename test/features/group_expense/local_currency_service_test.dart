import 'package:flutter_mvvm_riverpod/features/group_expense/repository/local_currency_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns one when currencies match', () async {
    final service = LocalCurrencyService();
    expect(
      await service.getExchangeRate(fromCurrency: 'MYR', toCurrency: 'MYR'),
      1,
    );
  });

  test('converts through deterministic local MYR rates', () async {
    final service = LocalCurrencyService();
    expect(
      await service.getExchangeRate(fromCurrency: 'USD', toCurrency: 'MYR'),
      4.45,
    );
  });
}
