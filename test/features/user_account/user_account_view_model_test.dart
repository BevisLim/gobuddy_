import 'package:flutter_mvvm_riverpod/features/user_account/model/user_account_model.dart';
import 'package:flutter_mvvm_riverpod/features/user_account/repository/user_account_repository.dart';
import 'package:flutter_mvvm_riverpod/features/user_account/ui/view_model/user_account_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts hosted verification without marking the user verified', () async {
    final repository = _FakeUserAccountRepository();
    final container = ProviderContainer(
      overrides: [
        userAccountRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(userAccountViewModelProvider);
    await Future<void>.delayed(Duration.zero);

    final notifier = container.read(userAccountViewModelProvider.notifier);
    expect(
      await notifier.startIdentityVerification(),
      'https://verify.didit.me/session/test',
    );

    final pending = container.read(userAccountViewModelProvider).user!;
    expect(pending.isVerified, isFalse);

    await notifier.updateProfile(
      const UserAccountProfileUpdate(
        username: 'new.username',
        gender: 'Non-binary',
        nationality: 'Malaysia',
        bio: 'Updated bio',
      ),
    );

    final updated = container.read(userAccountViewModelProvider).user!;
    expect(updated.username, 'new.username');
    expect(updated.nationality, 'Malaysia');
    expect(updated.bio, 'Updated bio');
  });
}

class _FakeUserAccountRepository extends UserAccountRepository {
  @override
  Future<UserAccount> fetchCurrentAccount() async {
    return const UserAccount(
      uid: 'test-user',
      email: 'test@example.com',
      phoneNumber: '',
      username: 'test.user',
    );
  }

  @override
  Future<UserAccount> updateProfile(
    String uid,
    UserAccountProfileUpdate update,
  ) async {
    return UserAccount(
      uid: uid,
      email: 'test@example.com',
      phoneNumber: '',
      username: update.username,
      profilePhoto: update.profilePhoto,
      gender: update.gender,
      nationality: update.nationality,
      bio: update.bio,
    );
  }

  @override
  Future<String> createDiditSession() async =>
      'https://verify.didit.me/session/test';
}
