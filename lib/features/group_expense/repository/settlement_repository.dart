import '../model/settlement.dart';
import '../model/settlement_receipt.dart';

abstract interface class SettlementRepository {
  Future<List<Settlement>> getSettlementsForTrip(int tripId);
  Future<int> createSettlement(
    Settlement settlement, {
    SettlementReceipt? receipt,
  });
  Future<void> updateSettlement(
    Settlement settlement, {
    SettlementReceipt? receipt,
    bool removeReceipt = false,
  });
  Future<void> deleteSettlement(int settlementId);
  Future<SettlementReceipt?> getReceipt(int settlementId);
  Future<Map<int, SettlementReceipt>> getReceiptsForTrip(int tripId);
  Future<List<Settlement>> getCompletedSettlements(int tripId);
  Future<List<Settlement>> getPendingSettlements(int tripId);
}
