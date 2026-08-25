import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_mvvm_riverpod/core/constants/constants.dart';
import '../../repository/authentication_repository.dart';
import '../state/settings_state.dart';

final settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, SettingsState>(
  SettingsViewModel.new,
);

class SettingsViewModel extends AsyncNotifier<SettingsState> {
  @override
  Future<SettingsState> build() async {
    final preferences = await SharedPreferences.getInstance();
    return SettingsState(
      tripMatchNotificationsEnabled: preferences.getBool(
            Constants.tripMatchNotificationsKey,
          ) ??
          true,
    );
  }

  Future<void> setTripMatchNotificationsEnabled(bool enabled) async {
    final current = state.value ?? const SettingsState();
    state = AsyncData(
      current.copyWith(tripMatchNotificationsEnabled: enabled),
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(Constants.tripMatchNotificationsKey, enabled);
  }

  Future<bool> signOut() async {
    final current = state.value ?? const SettingsState();
    state = AsyncData(current.copyWith(isSigningOut: true, clearError: true));
    try {
      await ref.read(authenticationRepositoryProvider).signOut();
      state = AsyncData(current.copyWith(isSigningOut: false));
      return true;
    } catch (error) {
      state = AsyncData(
        current.copyWith(isSigningOut: false, error: error.toString()),
      );
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    // TODO(account-deletion): Connect this confirmed action to the account
    // deletion backend when the endpoint and retention policy are available.
    return false;
  }
}
