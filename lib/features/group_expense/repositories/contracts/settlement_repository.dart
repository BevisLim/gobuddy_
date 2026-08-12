import '../../models/settlement.dart';
import '../../models/settlement_receipt.dart';

abstract interface class SettlementRepository {
  Future<List<Settlement>> getSettlementsForTrip(int tripId);
  Future<int> createSettlement(Settlement settlement,
      {SettlementReceipt? receipt});
  Future<void> updateSettlement(Settlement settlement,
      {SettlementReceipt? receipt});
  Future<List<Settlement>> getCompletedSettlements(int tripId);
}
