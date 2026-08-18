import 'package:flutter_mvvm_riverpod/features/user_account/model/user_account_model.dart';
import 'package:flutter_mvvm_riverpod/features/user_account/repository/user_account_repository.dart';
import 'package:flutter_mvvm_riverpod/features/user_account/ui/view_model/user_account_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification locks identity fields while profile fields stay editable',
      () async {
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
    expect(await notifier.completeIdentityVerification(), isTrue);

    final verified = container.read(userAccountViewModelProvider).user!;
    expect(verified.isVerified, isTrue);
    expect(verified.fullName, 'Test User');
    expect(verified.dateOfBirth, DateTime(2000, 1, 1));

    await notifier.updateProfile(
      const UserAccountProfileUpdate(
        username: 'new.username',
        gender: 'Non-binary',
        country: 'Malaysia',
        bio: 'Updated bio',
      ),
    );

    final updated = container.read(userAccountViewModelProvider).user!;
    expect(updated.username, 'new.username');
    expect(updated.country, 'Malaysia');
    expect(updated.bio, 'Updated bio');
    expect(updated.fullName, 'Test User');
    expect(updated.dateOfBirth, DateTime(2000, 1, 1));
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
  Future<void> updateProfile(
    String uid,
    UserAccountProfileUpdate update,
  ) async {}

  @override
  Future<IdentityVerificationResult> completeMockIdentityVerification() async {
    return IdentityVerificationResult(
      fullName: 'Test User',
      dateOfBirth: DateTime(2000, 1, 1),
    );
  }
}
