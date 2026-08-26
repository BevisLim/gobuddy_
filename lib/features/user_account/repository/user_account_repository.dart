import 'dart:io';

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
            'profile_photo_path, background_photo_path, verification_status, '
            'nationality, created_at',
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
        profilePhoto: _publicStorageUrl(
          'profile-images',
          row['profile_photo_path'] as String?,
        ),
        backgroundPhoto: _publicStorageUrl(
          'background-images',
          row['background_photo_path'] as String?,
        ),
        gender: row['gender'] as String?,
        nationality: (row['nationality'] as String?)?.trim(),
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

  Future<UserAccount> updateProfile(
    String uid,
    UserAccountProfileUpdate update,
  ) async {
    final authUser = supabase.auth.currentUser;
    if (authUser == null || authUser.id != uid) {
      throw const UserAccountLoadException(
        'Your session has expired. Please sign in again.',
      );
    }

    try {
      final profilePhotoPath = await _storagePathForUpdate(
        uid: uid,
        value: update.profilePhoto,
        bucket: 'profile-images',
        fileName: 'profile',
      );
      final backgroundPhotoPath = await _storagePathForUpdate(
        uid: uid,
        value: update.backgroundPhoto,
        bucket: 'background-images',
        fileName: 'background',
      );

      final values = <String, Object?>{
        'display_name': update.username.trim(),
        'bio': _nullableText(update.bio),
        'gender': _nullableText(update.gender),
        'nationality': _nullableText(update.nationality),
        'profile_photo_path': _nullableText(profilePhotoPath),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      // The current compact editor does not expose background-photo editing.
      // Preserve the stored path unless a caller explicitly supplies a value.
      if (update.backgroundPhoto != null) {
        values['background_photo_path'] = _nullableText(backgroundPhotoPath);
      }
      await supabase.from('user_accounts').update(values).eq('id', uid);

      return fetchCurrentAccount();
    } on UserAccountLoadException {
      rethrow;
    } on StorageException catch (error) {
      throw UserAccountLoadException(error.message);
    } on PostgrestException catch (error) {
      throw UserAccountLoadException(error.message);
    } catch (_) {
      throw const UserAccountLoadException(
        'Unable to save your profile. Check your connection and try again.',
      );
    }
  }

  Future<String?> _storagePathForUpdate({
    required String uid,
    required String? value,
    required String bucket,
    required String fileName,
  }) async {
    if (value == null || value.trim().isEmpty) return null;
    if (!_isLocalPath(value)) return _extractStoragePath(value, bucket);

    final extension = _imageExtension(value);
    final objectPath = '$uid/$fileName.$extension';
    await supabase.storage.from(bucket).uploadBinary(
          objectPath,
          await File(value).readAsBytes(),
          fileOptions: FileOptions(
            upsert: true,
            contentType: _imageContentType(extension),
          ),
        );
    return objectPath;
  }

  Future<String> createDiditSession() async {
    if (supabase.auth.currentSession == null) {
      throw const IdentityVerificationException(
        'Your session has expired. Please sign in again.',
      );
    }

    try {
      final response = await supabase.functions.invoke(
        'create-didit-session',
        body: const <String, Object?>{},
      );
      final data = response.data;
      if (data is! Map) {
        throw const IdentityVerificationException(
          'The verification service returned an invalid response.',
        );
      }

      final value = data['verification_url'];
      if (value is! String || value.trim().isEmpty) {
        throw const IdentityVerificationException(
          'The verification link was not returned. Please try again.',
        );
      }

      final uri = Uri.tryParse(value.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw const IdentityVerificationException(
          'The verification service returned an invalid link.',
        );
      }
      return uri.toString();
    } on IdentityVerificationException {
      rethrow;
    } on FunctionException catch (error) {
      throw IdentityVerificationException(
        error.status == 401
            ? 'Your session has expired. Please sign in again.'
            : 'Unable to start identity verification. Please try again.',
      );
    } catch (_) {
      throw const IdentityVerificationException(
        'Unable to start identity verification. Please try again.',
      );
    }
  }
}

String? _publicStorageUrl(String bucket, String? path) {
  final value = path?.trim();
  if (value == null || value.isEmpty) return null;
  if (!_isLocalPath(value)) return value;
  return supabase.storage.from(bucket).getPublicUrl(value);
}

String _extractStoragePath(String value, String bucket) {
  final uri = Uri.tryParse(value);
  if (uri == null) return value;
  final bucketIndex = uri.pathSegments.indexOf(bucket);
  if (bucketIndex < 0 || bucketIndex == uri.pathSegments.length - 1) {
    return value;
  }
  return uri.pathSegments.sublist(bucketIndex + 1).join('/');
}

bool _isLocalPath(String? value) {
  if (value == null || value.trim().isEmpty) return false;
  final uri = Uri.tryParse(value);
  return uri == null || !(uri.scheme == 'http' || uri.scheme == 'https');
}

String? _nullableText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _imageExtension(String path) {
  final cleanPath = path.split('?').first.toLowerCase();
  if (cleanPath.endsWith('.png')) return 'png';
  if (cleanPath.endsWith('.webp')) return 'webp';
  return 'jpg';
}

String _imageContentType(String extension) => switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

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

class IdentityVerificationException implements Exception {
  const IdentityVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

final userAccountRepositoryProvider = Provider<UserAccountRepository>((ref) {
  return const UserAccountRepository();
});
