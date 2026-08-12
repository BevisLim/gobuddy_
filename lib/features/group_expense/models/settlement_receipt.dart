class SettlementReceipt {
  const SettlementReceipt(
      {this.receiptId,
      required this.settlementId,
      required this.imagePath,
      required this.uploadedAt});
  final int? receiptId;
  final int settlementId;
  final String imagePath;
  final DateTime uploadedAt;
  factory SettlementReceipt.fromMap(Map<String, Object?> map) =>
      SettlementReceipt(
          receiptId: map['receipt_id'] as int?,
          settlementId: map['settlement_id']! as int,
          imagePath: map['image_path']! as String,
          uploadedAt: DateTime.parse(map['uploaded_at']! as String));
  Map<String, Object?> toMap({int? settlementIdOverride}) => {
        if (receiptId != null) 'receipt_id': receiptId,
        'settlement_id': settlementIdOverride ?? settlementId,
        'image_path': imagePath,
        'uploaded_at': uploadedAt.toIso8601String(),
      };
}
