import 'package:flutter_mvvm_riverpod/features/group_expense/model/budget_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BudgetValidation', () {
    test('requires a name', () {
      expect(BudgetValidation.name('   '), isNotNull);
      expect(BudgetValidation.name('KL Trip'), isNull);
    });

    test('requires a positive numeric amount', () {
      expect(BudgetValidation.amount(''), isNotNull);
      expect(BudgetValidation.amount('0'), isNotNull);
      expect(BudgetValidation.amount('-10'), isNotNull);
      expect(BudgetValidation.amount('3000.50'), isNull);
    });

    test('requires a currency', () {
      expect(BudgetValidation.currency(''), isNotNull);
      expect(BudgetValidation.currency('MYR'), isNull);
    });
  });
}
