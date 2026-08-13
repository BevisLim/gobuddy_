import 'package:sqflite/sqflite.dart';

import '../model/settlement.dart';
import '../model/settlement_receipt.dart';
import 'settlement_repository.dart';

class SqliteSettlementRepository implements SettlementRepository {
  const SqliteSettlementRepository(this.database);
  final Database database;

  @override
  Future<int> createSettlement(
    Settlement settlement, {
    SettlementReceipt? receipt,
  }) async {
    _validate(settlement);
    return database.transaction((transaction) async {
      final settlementId =
          await transaction.insert('settlements', settlement.toMap());
      if (receipt != null) {
        await transaction.insert(
          'settlement_receipts',
          _receiptMap(receipt, settlementId),
        );
      }
      return settlementId;
    });
  }

  @override
  Future<List<Settlement>> getCompletedSettlements(int tripId) async =>
      _getByStatus(tripId, SettlementStatus.completed);
  @override
  Future<List<Settlement>> getPendingSettlements(int tripId) async =>
      _getByStatus(tripId, SettlementStatus.pending);
  @override
  Future<List<Settlement>> getSettlementsForTrip(int tripId) async {
    final rows = await database.query(
      'settlements',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'settlement_date DESC, settlement_id DESC',
    );
    return rows.map(Settlement.fromMap).toList(growable: false);
  }

  @override
  Future<void> updateSettlement(
    Settlement settlement, {
    SettlementReceipt? receipt,
    bool removeReceipt = false,
  }) async {
    final settlementId = settlement.settlementId;
    if (settlementId == null) throw ArgumentError('settlementId is required');
    _validate(settlement);
    await database.transaction((transaction) async {
      final updated = await transaction.update(
        'settlements',
        settlement.toMap()..remove('settlement_id'),
        where: 'settlement_id = ?',
        whereArgs: [settlementId],
      );
      if (updated == 0) throw StateError('Settlement not found');
      if (removeReceipt || receipt != null) {
        await transaction.delete(
          'settlement_receipts',
          where: 'settlement_id = ?',
          whereArgs: [settlementId],
        );
      }
      if (receipt != null) {
        await transaction.insert(
          'settlement_receipts',
          _receiptMap(receipt, settlementId),
        );
      }
    });
  }

  @override
  Future<void> deleteSettlement(int settlementId) => database.delete(
        'settlements',
        where: 'settlement_id = ?',
        whereArgs: [settlementId],
      );

  @override
  Future<SettlementReceipt?> getReceipt(int settlementId) async {
    final rows = await database.query(
      'settlement_receipts',
      where: 'settlement_id = ?',
      whereArgs: [settlementId],
      limit: 1,
    );
    return rows.isEmpty ? null : SettlementReceipt.fromMap(rows.first);
  }

  @override
  Future<Map<int, SettlementReceipt>> getReceiptsForTrip(int tripId) async {
    final rows = await database.rawQuery('''
      SELECT receipt.* FROM settlement_receipts receipt
      INNER JOIN settlements settlement
        ON settlement.settlement_id = receipt.settlement_id
      WHERE settlement.trip_id = ?
    ''', [tripId]);
    return {
      for (final row in rows)
        row['settlement_id']! as int: SettlementReceipt.fromMap(row),
    };
  }

  Future<List<Settlement>> _getByStatus(
    int tripId,
    SettlementStatus status,
  ) async {
    final rows = await database.query(
      'settlements',
      where: 'trip_id = ? AND status = ?',
      whereArgs: [tripId, status.name],
      orderBy: 'settlement_date DESC, settlement_id DESC',
    );
    return rows.map(Settlement.fromMap).toList(growable: false);
  }

  void _validate(Settlement settlement) {
    if (settlement.payerId == settlement.payeeId) {
      throw ArgumentError('Payer and payee must be different');
    }
    if (settlement.amount <= 0 || settlement.paymentMethod.trim().isEmpty) {
      throw ArgumentError('Invalid settlement data');
    }
  }

  Map<String, Object?> _receiptMap(
    SettlementReceipt receipt,
    int settlementId,
  ) =>
      {
        'settlement_id': settlementId,
        'image_path': receipt.imagePath,
        'uploaded_at': receipt.uploadedAt.toIso8601String(),
      };
}
