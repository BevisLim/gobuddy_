class ExpenseParticipant {
  const ExpenseParticipant(
      {required this.expenseId,
      required this.userId,
      required this.shareAmount,
      this.sharePercentage});
  final int expenseId;
  final int userId;
  final double shareAmount;
  final double? sharePercentage;
  factory ExpenseParticipant.fromMap(Map<String, Object?> map) =>
      ExpenseParticipant(
          expenseId: map['expense_id']! as int,
          userId: map['user_id']! as int,
          shareAmount: (map['share_amount']! as num).toDouble(),
          sharePercentage: (map['share_percentage'] as num?)?.toDouble());
  Map<String, Object?> toMap({int? expenseIdOverride}) => {
        'expense_id': expenseIdOverride ?? expenseId,
        'user_id': userId,
        'share_amount': shareAmount,
        'share_percentage': sharePercentage,
      };
}
