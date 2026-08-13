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
      name: 'Alex Morgan',
      email: 'alex.morgan@gobuddy.app',
      phoneNumber: '+1 (555) 019-2834',
    );
  }

  /// Simulates updating the database profile row locally.
  Future<void> updateAccountName(String uid, String newName) async {
    // Simulates database update latency
    await Future.delayed(const Duration(milliseconds: 300));
  }
}

/// Exposes the mock repository layer. 
/// Later, we will only change this internal implementation to use SupabaseClient.
final userAccountRepositoryProvider = Provider<UserAccountRepository>((ref) {
  return const UserAccountRepository();
});