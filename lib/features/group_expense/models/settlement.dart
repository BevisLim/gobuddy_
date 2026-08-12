enum SettlementStatus { pending, completed, rejected }

class Settlement {
  const Settlement(
      {this.settlementId,
      required this.tripId,
      required this.payerId,
      required this.payeeId,
      required this.amount,
      required this.paymentMethod,
      required this.settlementDate,
      required this.status,
      this.notes,
      required this.createdAt});
  final int? settlementId;
  final int tripId;
  final int payerId;
  final int payeeId;
  final double amount;
  final String paymentMethod;
  final DateTime settlementDate;
  final SettlementStatus status;
  final String? notes;
  final DateTime createdAt;
  factory Settlement.fromMap(Map<String, Object?> map) => Settlement(
      settlementId: map['settlement_id'] as int?,
      tripId: map['trip_id']! as int,
      payerId: map['payer_id']! as int,
      payeeId: map['payee_id']! as int,
      amount: (map['amount']! as num).toDouble(),
      paymentMethod: map['payment_method']! as String,
      settlementDate: DateTime.parse(map['settlement_date']! as String),
      status: SettlementStatus.values.byName(map['status']! as String),
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String));
  Map<String, Object?> toMap() => {
        if (settlementId != null) 'settlement_id': settlementId,
        'trip_id': tripId,
        'payer_id': payerId,
        'payee_id': payeeId,
        'amount': amount,
        'payment_method': paymentMethod,
        'settlement_date': settlementDate.toIso8601String(),
        'status': status.name,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}
