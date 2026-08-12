class ExpenseReceipt {
  const ExpenseReceipt({
    this.receiptId,
    required this.expenseId,
    required this.imagePath,
    required this.uploadedAt,
  });

  final int? receiptId;
  final int expenseId;
  final String imagePath;
  final DateTime uploadedAt;

  Map<String, Object?> toMap() => {
        if (receiptId != null) 'receipt_id': receiptId,
        'expense_id': expenseId,
        'image_path': imagePath,
        'uploaded_at': uploadedAt.toIso8601String(),
      };

  factory ExpenseReceipt.fromMap(Map<String, Object?> map) => ExpenseReceipt(
        receiptId: map['receipt_id']! as int,
        expenseId: map['expense_id']! as int,
        imagePath: map['image_path']! as String,
        uploadedAt: DateTime.parse(map['uploaded_at']! as String),
      );
}
