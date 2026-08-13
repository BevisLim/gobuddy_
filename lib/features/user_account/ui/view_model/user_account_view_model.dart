import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/user_account_model.dart';
import '../../repository/user_account_repository.dart';
import '../state/user_account_state.dart';

// 1. Modern NotifierProvider definition matching your team template
final userAccountViewModelProvider =
    NotifierProvider<UserAccountViewModel, UserAccountState>(
  UserAccountViewModel.new,
);

// 2. The modern Notifier class managing your module state lifecycle
class UserAccountViewModel extends Notifier<UserAccountState> {
  @override
  UserAccountState build() {
    // Fire off async data initialization so it doesn't block layout threads
    _initLoad();
    
    // Return standard initial loading state immediately
    return const UserAccountState(isLoading: true);
  }

  /// Private initialization method to load profile data seamlessly
  Future<void> _initLoad() async {
    final repository = ref.read(userAccountRepositoryProvider);
    try {
      final initialUser = await repository.fetchCurrentAccount();
      state = state.copyWith(user: initialUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Change the currently active sub-page within the user account module
  void goTo(UserAccountPage page) => state = state.copyWith(page: page);

  /// Updates user profile information and updates the repository layer
  Future<void> updateProfileName(String newName) async {
    if (state.user == null || newName.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);
    final repository = ref.read(userAccountRepositoryProvider);

    try {
      // Sync update change to the data layer source
      await repository.updateAccountName(state.user!.uid, newName);
      
      // Mutate local state values and slide back to the main profile page
      final updatedUser = state.user!.copyWith(name: newName);
      state = state.copyWith(
        user: updatedUser,
        page: UserAccountPage.profile,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}