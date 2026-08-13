class SettlementSuggestion {
  const SettlementSuggestion({
    required this.payerId,
    required this.payeeId,
    required this.amount,
  });

  final int payerId;
  final int payeeId;
  final double amount;
}
