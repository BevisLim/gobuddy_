class TripBudget {
  const TripBudget(
      {this.budgetId,
      required this.tripId,
      required this.budgetName,
      required this.budgetAmount,
      required this.baseCurrency,
      this.notes,
      required this.createdAt,
      required this.updatedAt});
  final int? budgetId;
  final int tripId;
  final String budgetName;
  final double budgetAmount;
  final String baseCurrency;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TripBudget.fromMap(Map<String, Object?> map) => TripBudget(
        budgetId: map['budget_id'] as int?,
        tripId: map['trip_id']! as int,
        budgetName: map['budget_name']! as String,
        budgetAmount: (map['budget_amount']! as num).toDouble(),
        baseCurrency: map['base_currency']! as String,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );
  Map<String, Object?> toMap() => {
        if (budgetId != null) 'budget_id': budgetId,
        'trip_id': tripId,
        'budget_name': budgetName,
        'budget_amount': budgetAmount,
        'base_currency': baseCurrency,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
  TripBudget copyWith(
          {int? budgetId,
          String? budgetName,
          double? budgetAmount,
          String? baseCurrency,
          String? notes,
          DateTime? updatedAt}) =>
      TripBudget(
          budgetId: budgetId ?? this.budgetId,
          tripId: tripId,
          budgetName: budgetName ?? this.budgetName,
          budgetAmount: budgetAmount ?? this.budgetAmount,
          baseCurrency: baseCurrency ?? this.baseCurrency,
          notes: notes ?? this.notes,
          createdAt: createdAt,
          updatedAt: updatedAt ?? this.updatedAt);
}
