import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/user_account_model.dart';

class UserAccountRepository {
  const UserAccountRepository();

  /// Simulates fetching a profile from Supabase with local mock data.
  Future<UserAccount> fetchCurrentAccount() async {
    // Simulates network latency (400ms) so you can test loading spinners!
    await Future.delayed(const Duration(milliseconds: 400));

    return const UserAccount(
      uid: 'mock_supabase_user_101',
      email: 'alex.morgan@gobuddy.app',
      phoneNumber: '+1 (555) 019-2834',
      username: 'alex.morgan',
      backgroundPhoto:
          'https://images.unsplash.com/photo-1498307833015-e7b400441eb8?auto=format&fit=crop&w=1200&q=85',
      profilePhoto: 'assets/images/avatar.webp',
      gender: 'Male',
      country: 'United States',
      bio: 'Curious traveller who enjoys meaningful journeys and new places.',
    );
  }

  Future<void> updateProfile(
    String uid,
    UserAccountProfileUpdate update,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<IdentityVerificationResult> completeMockIdentityVerification() async {
    await Future.delayed(const Duration(milliseconds: 600));

    // TODO(identity-verification): Replace this mock extraction result with
    // verified OCR/document-provider output when that backend is available.
    return IdentityVerificationResult(
      fullName: 'Test User',
      dateOfBirth: DateTime(2000, 1, 1),
    );
  }
}

/// Exposes the mock repository layer.
/// Later, we will only change this internal implementation to use SupabaseClient.
final userAccountRepositoryProvider = Provider<UserAccountRepository>((ref) {
  return const UserAccountRepository();
});
