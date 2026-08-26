import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../common/remote/supabase_client.dart';
import '../model/user_account_model.dart';

class UserAccountRepository {
  const UserAccountRepository();

  Future<UserAccount> fetchCurrentAccount() async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) {
      throw const UserAccountLoadException(
        'Your session has expired. Please sign in again.',
      );
    }

    try {
      final row = await supabase
          .from('user_accounts')
          .select(
            'id, display_name, date_of_birth, gender, bio, '
            'profile_photo_path, verification_status, created_at',
          )
          .eq('id', authUser.id)
          .maybeSingle();
      if (row == null) {
        throw const UserAccountLoadException(
          'Your profile is not set up yet.',
        );
      }

      return UserAccount(
        uid: row['id'] as String,
        email: authUser.email ?? '',
        phoneNumber: authUser.phone ?? '',
        username: (row['display_name'] as String?)?.trim() ?? '',
        profilePhoto: row['profile_photo_path'] as String?,
        gender: row['gender'] as String?,
        dateOfBirth: _parseDate(row['date_of_birth']),
        joinedAt: _parseDate(row['created_at']),
        bio: (row['bio'] as String?)?.trim() ?? '',
        isVerified: row['verification_status'] == 'verified',
      );
    } on UserAccountLoadException {
      rethrow;
    } on PostgrestException {
      throw const UserAccountLoadException(
        'Unable to load your profile. Check your connection and try again.',
      );
    } catch (_) {
      throw const UserAccountLoadException(
        'Unable to load your profile. Please try again.',
      );
    }
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

DateTime? _parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

class UserAccountLoadException implements Exception {
  const UserAccountLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

final userAccountRepositoryProvider = Provider<UserAccountRepository>((ref) {
  return const UserAccountRepository();
});
