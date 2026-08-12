import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../model/balance_calculator.dart';
import '../../model/money_utils.dart';
import '../../model/traveller_balance.dart';
import '../../repository/group_expense_providers.dart';
import '../state/balance_state.dart';

part 'balance_view_model.g.dart';

@riverpod
class BalanceViewModel extends _$BalanceViewModel {
  @override
  Future<BalanceState> build(int tripId) async {
    final session = ref.watch(appSessionProvider);
    final expenseRepositoryFuture = ref.watch(expenseRepositoryProvider.future);
    final settlementRepositoryFuture =
        ref.watch(settlementRepositoryProvider.future);
    final travellerRepositoryFuture =
        ref.watch(travellerRepositoryProvider.future);
    final tripRepositoryFuture = ref.watch(tripRepositoryProvider.future);
    final budgetRepositoryFuture = ref.watch(budgetRepositoryProvider.future);
    final expenseRepository = await expenseRepositoryFuture;
    final settlementRepository = await settlementRepositoryFuture;
    final travellerRepository = await travellerRepositoryFuture;
    final tripRepository = await tripRepositoryFuture;
    final budgetRepository = await budgetRepositoryFuture;

    final travellers = await travellerRepository.getTravellersForTrip(tripId);
    final expenseBalances =
        await expenseRepository.calculateNetExpenseBalances(tripId);
    final completed =
        await settlementRepository.getCompletedSettlements(tripId);
    final pending = await settlementRepository.getPendingSettlements(tripId);
    final trip = await tripRepository.getTripById(tripId);
    final budget = await budgetRepository.getBudgetForTrip(tripId);
    final netBalances = BalanceCalculator.applyCompletedSettlements(
      expenseBalances: {
        for (final traveller in travellers)
          traveller.userId: expenseBalances[traveller.userId] ?? 0,
      },
      settlements: completed,
    );
    final pendingUserIds = <int>{
      for (final settlement in pending) ...[
        settlement.payerId,
        settlement.payeeId,
      ],
    };
    final balances = [
      for (final traveller in travellers)
        TravellerBalance(
          userId: traveller.userId,
          name: traveller.name,
          initials: traveller.initials,
          netBalance: MoneyUtils.roundMoney(
            netBalances[traveller.userId] ?? 0,
          ),
          status: _status(
            netBalances[traveller.userId] ?? 0,
            pendingUserIds.contains(traveller.userId),
          ),
        ),
    ];
    return BalanceState(
      tripId: tripId,
      currentUserId: session.currentUserId,
      currency: budget?.baseCurrency ?? 'MYR',
      tripName: trip?.tripName ?? 'Current Trip',
      balances: balances,
      suggestions: BalanceCalculator.suggestions(netBalances),
    );
  }

  Future<void> refresh() async => ref.invalidateSelf();

  TravellerBalanceStatus _status(double balance, bool hasPending) {
    if (hasPending) return TravellerBalanceStatus.pendingConfirmation;
    final cents = MoneyUtils.toCents(balance);
    if (cents == 0) return TravellerBalanceStatus.settled;
    if (cents < 0) return TravellerBalanceStatus.needsPayment;
    return TravellerBalanceStatus.owed;
  }
}
