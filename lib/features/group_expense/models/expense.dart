enum SplitMethod { equal, custom, percentage }

class Expense {
  const Expense(
      {this.expenseId,
      required this.tripId,
      required this.paidByUserId,
      required this.categoryId,
      required this.title,
      required this.originalAmount,
      required this.currencyCode,
      required this.exchangeRate,
      required this.baseAmount,
      required this.expenseDate,
      this.notes,
      this.splitMethod = SplitMethod.equal,
      required this.createdAt,
      required this.updatedAt});
  final int? expenseId;
  final int tripId;
  final int paidByUserId;
  final int categoryId;
  final String title;
  final double originalAmount;
  final String currencyCode;
  final double exchangeRate;
  final double baseAmount;
  final DateTime expenseDate;
  final String? notes;
  final SplitMethod splitMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
      expenseId: map['expense_id'] as int?,
      tripId: map['trip_id']! as int,
      paidByUserId: map['paid_by_user_id']! as int,
      categoryId: map['category_id']! as int,
      title: map['title']! as String,
      originalAmount: (map['original_amount']! as num).toDouble(),
      currencyCode: map['currency_code']! as String,
      exchangeRate: (map['exchange_rate']! as num).toDouble(),
      baseAmount: (map['base_amount']! as num).toDouble(),
      expenseDate: DateTime.parse(map['expense_date']! as String),
      notes: map['notes'] as String?,
      splitMethod: SplitMethod.values
          .byName((map['split_method'] as String?) ?? 'equal'),
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String));

  Map<String, Object?> toMap() => {
        if (expenseId != null) 'expense_id': expenseId,
        'trip_id': tripId,
        'paid_by_user_id': paidByUserId,
        'category_id': categoryId,
        'title': title,
        'original_amount': originalAmount,
        'currency_code': currencyCode,
        'exchange_rate': exchangeRate,
        'base_amount': baseAmount,
        'expense_date': expenseDate.toIso8601String(),
        'notes': notes,
        'split_method': splitMethod.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
