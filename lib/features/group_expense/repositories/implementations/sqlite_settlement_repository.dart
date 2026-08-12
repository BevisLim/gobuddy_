import '../../../../core/database/app_database.dart';
import '../../models/settlement.dart';
import '../../models/settlement_receipt.dart';
import '../contracts/settlement_repository.dart';

class SqliteSettlementRepository implements SettlementRepository {
  const SqliteSettlementRepository(this._database);
  final AppDatabase _database;
  void _validate(Settlement settlement) {
    if (settlement.payerId == settlement.payeeId) {
      throw ArgumentError('Payer and payee must differ');
    }
  }

  @override
  Future<int> createSettlement(Settlement settlement,
      {SettlementReceipt? receipt}) async {
    _validate(settlement);
    final db = await _database.database;
    return db.transaction((txn) async {
      final id = await txn.insert('settlements', settlement.toMap());
      if (receipt != null) {
        await txn.insert(
            'settlement_receipts', receipt.toMap(settlementIdOverride: id));
      }
      return id;
    });
  }

  @override
  Future<List<Settlement>> getCompletedSettlements(int tripId) async =>
      _query(tripId, status: SettlementStatus.completed);
  @override
  Future<List<Settlement>> getSettlementsForTrip(int tripId) => _query(tripId);
  Future<List<Settlement>> _query(int tripId,
      {SettlementStatus? status}) async {
    final rows = await (await _database.database).query('settlements',
        where: status == null ? 'trip_id = ?' : 'trip_id = ? AND status = ?',
        whereArgs: status == null ? [tripId] : [tripId, status.name],
        orderBy: 'settlement_date DESC');
    return rows.map(Settlement.fromMap).toList(growable: false);
  }

  @override
  Future<void> updateSettlement(Settlement settlement,
      {SettlementReceipt? receipt}) async {
    final id = settlement.settlementId;
    if (id == null) throw ArgumentError('Settlement id is required');
    _validate(settlement);
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.update('settlements', settlement.toMap(),
          where: 'settlement_id = ?', whereArgs: [id]);
      await txn.delete('settlement_receipts',
          where: 'settlement_id = ?', whereArgs: [id]);
      if (receipt != null) {
        await txn.insert(
            'settlement_receipts', receipt.toMap(settlementIdOverride: id));
      }
    });
  }
}
