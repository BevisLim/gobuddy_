import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvvm_riverpod/app.dart';
import 'package:flutter_mvvm_riverpod/core/services/local_currency_service.dart';
import 'package:flutter_mvvm_riverpod/core/utils/money_utils.dart';

void main() {
  test('money utilities use cent-safe rounding', () {
    expect(MoneyUtils.toCents(100 / 3), 3333);
    expect(MoneyUtils.fromCents(94500), 945);
    expect(MoneyUtils.moneyEquals(0.1 + 0.2, 0.3), isTrue);
  });

  test('local currency service returns development rates', () async {
    final service = LocalCurrencyService();
    expect(
      await service.getExchangeRate(
        fromCurrency: 'USD',
        toCurrency: 'MYR',
      ),
      4.65,
    );
    expect(
      await service.getExchangeRate(
        fromCurrency: 'MYR',
        toCurrency: 'MYR',
      ),
      1,
    );
  });

  testWidgets('Phase 1 dashboard shell launches', (tester) async {
    await tester.pumpWidget(const GoBuddyApp());
    await tester.pumpAndSettle();
    expect(find.text('Kuala Lumpur MY'), findsOneWidget);
    expect(find.text('RM3,000'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
