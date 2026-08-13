import '../../model/settlement_suggestion.dart';
import '../../model/traveller_balance.dart';

class BalanceState {
  const BalanceState({
    required this.tripId,
    required this.currentUserId,
    required this.currency,
    this.tripName = 'Current Trip',
    this.balances = const [],
    this.suggestions = const [],
  });

  final int tripId;
  final int currentUserId;
  final String currency;
  final String tripName;
  final List<TravellerBalance> balances;
  final List<SettlementSuggestion> suggestions;

  TravellerBalance? get currentUserBalance {
    for (final balance in balances) {
      if (balance.userId == currentUserId) return balance;
    }
    return null;
  }

  double get youOwe {
    final net = currentUserBalance?.netBalance ?? 0;
    return net < 0 ? -net : 0;
  }

  double get owedToYou {
    final net = currentUserBalance?.netBalance ?? 0;
    return net > 0 ? net : 0;
  }

  double get net => currentUserBalance?.netBalance ?? 0;

  String travellerName(int userId) {
    for (final balance in balances) {
      if (balance.userId == userId) return balance.name;
    }
    return 'Traveller';
  }
}
