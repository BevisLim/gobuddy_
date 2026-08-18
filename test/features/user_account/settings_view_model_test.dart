import 'package:flutter_mvvm_riverpod/core/constants/constants.dart';
import 'package:flutter_mvvm_riverpod/features/user_account/ui/view_model/settings_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      Constants.tripMatchNotificationsKey: true,
      Constants.isLoginKey: true,
    });
  });

  test('persists Trip Matches preference and signs out locally', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsViewModelProvider.future);
    final notifier = container.read(settingsViewModelProvider.notifier);

    await notifier.setTripMatchNotificationsEnabled(false);
    expect(
      container
          .read(settingsViewModelProvider)
          .value!
          .tripMatchNotificationsEnabled,
      isFalse,
    );

    var preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(Constants.tripMatchNotificationsKey),
      isFalse,
    );

    expect(await notifier.signOut(), isTrue);
    preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool(Constants.isLoginKey), isFalse);
  });
}
