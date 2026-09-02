import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mvvm_riverpod/core/constants/constants.dart';
import 'package:flutter_mvvm_riverpod/generated/locale_keys.g.dart';
import 'package:flutter_mvvm_riverpod/features/common/remote/supabase_client.dart';

part 'authentication_repository.g.dart';

@riverpod
AuthenticationRepository authenticationRepository(Ref ref) {
  return AuthenticationRepository();
}

class AuthenticationRepository {
  const AuthenticationRepository();

  Future<void> sendRegistrationLink(String email) async {
    try {
      if (supabase.auth.currentSession != null) {
        await supabase.auth.signOut(scope: SignOutScope.local);
      }
      await supabase.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: Constants.supabaseLoginCallback,
        shouldCreateUser: true,
        data: const {'registration_pending': true},
      );
      await setRegistrationPending(true, email: email.trim());
    } on AuthException catch (error) {
      throw Exception(_friendlyRegistrationError(error));
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Unable to create account. Please try again.');
    }
  }

  Future<void> setPassword(String password) async {
    if (supabase.auth.currentSession == null) {
      throw Exception(
        'Your verification session is missing or expired. Request a new link.',
      );
    }
    try {
      await supabase.auth.updateUser(UserAttributes(password: password));
      await setRegistrationPending(false);
      // Email-link verification creates a session. End it so registration
      // always finishes at the normal login screen.
      // Email verification creates an authenticated session. End that
      // temporary session so registration finishes at the login screen and
      // the user explicitly signs in with the credentials they just created.
      await supabase.auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('password')) {
        throw Exception(
          'Use at least 8 characters, including uppercase, lowercase, a number, and a special character.',
        );
      }
      throw Exception('Unable to save your password. Please try again.');
    } catch (_) {
      throw Exception('Unable to save your password. Please try again.');
    }
  }

  Future<bool> isRegistrationPending() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool(Constants.registrationPendingKey) ?? false;
    final pendingEmail = prefs
        .getString(Constants.registrationPendingEmailKey)
        ?.toLowerCase();
    final currentEmail = supabase.auth.currentUser?.email?.toLowerCase();
    return pending && pendingEmail != null && pendingEmail == currentEmail;
  }

  Future<void> setRegistrationPending(bool value, {String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.registrationPendingKey, value);
    if (value && email != null) {
      await prefs.setString(Constants.registrationPendingEmailKey, email);
    } else if (!value) {
      await prefs.remove(Constants.registrationPendingEmailKey);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: Constants.supabasePasswordRecoveryCallback,
      );
    } on AuthException catch (error) {
      throw Exception(_friendlyPasswordRecoveryError(error));
    } catch (_) {
      throw Exception(
        'Unable to send the reset link. Check your connection and try again.',
      );
    }
  }

  Future<void> updateRecoveredPassword(String password) async {
    if (supabase.auth.currentSession == null) {
      throw Exception(
        'This password reset link is invalid or expired. Request a new link.',
      );
    }

    try {
      await supabase.auth.updateUser(UserAttributes(password: password));
      try {
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // The password is already updated. Login navigation still prevents
        // continuing into the authenticated app from the recovery flow.
      }
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('password') || message.contains('weak')) {
        throw Exception(
          'Use at least 8 characters, including uppercase, lowercase, a number, and a special character.',
        );
      }
      if (message.contains('expired') ||
          message.contains('invalid') ||
          message.contains('session')) {
        throw Exception(
          'This password reset link is invalid or expired. Request a new link.',
        );
      }
      throw Exception('Unable to reset your password. Please try again.');
    } catch (_) {
      throw Exception('Unable to reset your password. Please try again.');
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final email = supabase.auth.currentUser?.email;
    if (email == null || supabase.auth.currentSession == null) {
      throw Exception('Your session has expired. Please sign in again.');
    }
    if (oldPassword == newPassword) {
      throw Exception('Your new password must be different from your old password.');
    }

    try {
      // Supabase requires a fresh password sign-in to prove the current
      // password is valid before this sensitive account change.
      await supabase.auth.signInWithPassword(
        email: email,
        password: oldPassword,
      );
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login') ||
          message.contains('invalid credentials') ||
          message.contains('email or password')) {
        throw Exception('Your old password is incorrect.');
      }
      if (message.contains('same password') ||
          message.contains('different from the old')) {
        throw Exception(
          'Your new password must be different from your old password.',
        );
      }
      if (message.contains('password') || message.contains('weak')) {
        throw Exception(
          'Use at least 8 characters, including uppercase, lowercase, a number, and a special character.',
        );
      }
      throw Exception('Unable to change your password. Please try again.');
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('Unable to change your password. Please try again.');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      // A pending email-link registration must never send a Google user to
      // the email-only Set Password flow.
      await setRegistrationPending(false);
      final launched = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // On Flutter web, return to the port used by `flutter run` instead
        // of Supabase's project-wide Site URL (often localhost:3000).
        redirectTo: kIsWeb ? Uri.base.origin : Constants.supabaseLoginCallback,
      );
      if (!launched) {
        throw Exception('Unable to open Google sign-in. Please try again.');
      }
    } on AuthException catch (error) {
      throw Exception(_friendlyGoogleSignInError(error));
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Unable to start Google sign-in. Please try again.');
    }
  }

  Future<bool> hasCurrentUserProfile() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Your sign-in session is missing. Please try again.');
    }

    try {
      final profile = await supabase
          .from('user_accounts')
          .select('display_name, date_of_birth')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return false;
      final displayName = (profile['display_name'] as String?)?.trim() ?? '';
      final dateOfBirth = profile['date_of_birth'];
      return displayName.isNotEmpty &&
          dateOfBirth is String &&
          dateOfBirth.trim().isNotEmpty;
    } on PostgrestException {
      throw Exception(
        'Unable to load your profile. Check your connection and try again.',
      );
    }
  }

  Future<bool> hasCompletedProfileOnboarding() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Your sign-in session is missing. Please try again.');
    }

    try {
      final profile = await supabase
          .from('user_accounts')
          .select('onboarding_completed')
          .eq('id', userId)
          .maybeSingle();
      return profile?['onboarding_completed'] == true;
    } on PostgrestException {
      throw Exception(
        'Unable to load your profile. Check your connection and try again.',
      );
    }
  }

  Future<AuthResponse> signInWithApple() async {
    // TODO: fake data
    return AuthResponse(
      user: User(
        id: '',
        appMetadata: {},
        userMetadata: {},
        aud: '',
        createdAt: '',
        email: 'henry@apple.com',
      ),
    );

    // ignore: dead_code
    try {
      final rawNonce = supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception(LocaleKeys.idTokenNotFound.tr());
      }

      final result = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      return result;
    } on AuthException catch (error) {
      throw Exception(error.message);
    } catch (error) {
      throw Exception(LocaleKeys.unexpectedErrorOccurred.tr());
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      if (supabase.auth.currentSession != null ||
          supabase.auth.currentUser != null) {
        throw const AuthException('The Supabase session could not be cleared.');
      }

      try {
        await Purchases.logOut();
      } catch (_) {
        // Supabase is the authentication source of truth. A RevenueCat cleanup
        // failure must not restore or misreport an already-ended auth session.
      }
    } on AuthException {
      throw Exception('Unable to sign out. Please try again.');
    } catch (_) {
      throw Exception('Unable to sign out. Please try again.');
    }
  }

  Future<void> deleteAccount() async {
    if (supabase.auth.currentSession == null) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    try {
      final response = await supabase.functions.invoke('delete-account');
      final data = response.data;
      if (data is! Map || data['deleted'] != true) {
        throw Exception('Unable to delete your account. Please try again.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(Constants.isLoginKey);
      await prefs.remove(Constants.isExistAccountKey);
      await prefs.remove(Constants.isGuestModeKey);
      await prefs.remove(Constants.registrationPendingKey);
      await prefs.remove(Constants.registrationPendingEmailKey);
      try {
        await Purchases.logOut();
      } catch (_) {
        // Database deletion has already completed. Local third-party cleanup
        // must not report the account as still active.
      }
      try {
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Deleting auth.users invalidates the session on the server.
      }
    } on FunctionException catch (error) {
      final data = error.details;
      final message = data is Map ? data['error']?.toString() : null;
      throw Exception(message ?? 'Unable to delete your account. Please try again.');
    } on Exception {
      rethrow;
    } catch (_) {
      throw Exception('Unable to delete your account. Please try again.');
    }
  }

  Future<bool> isLogin() async {
    return supabase.auth.currentUser != null;
  }

  // TODO: remove this when integrating real auth
  Future<void> setIsLogin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.isLoginKey, value);
  }

  Future<bool> isExistAccount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(Constants.isExistAccountKey) ?? false;
  }

  Future<void> setIsExistAccount(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.isExistAccountKey, value);
  }
  // END TODO

  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(Constants.isGuestModeKey) ?? false;
  }

  Future<void> setIsGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(Constants.isGuestModeKey, true);
  }
}

String _friendlyRegistrationError(AuthException error) {
  final message = error.message.toLowerCase();
  if (message.contains('already registered') ||
      message.contains('already exists') ||
      message.contains('user already')) {
    return 'An account with this email already exists. Please log in instead.';
  }
  if (message.contains('password')) {
    return 'Use at least 8 characters, including uppercase, lowercase, a number, and a special character.';
  }
  if (message.contains('email')) {
    return 'Please enter a valid email address.';
  }
  if (message.contains('network') ||
      message.contains('socket') ||
      message.contains('connection')) {
    return 'Unable to connect. Check your internet connection and try again.';
  }
  return 'Unable to send the verification link. Please try again.';
}

String _friendlyGoogleSignInError(AuthException error) {
  final message = error.message.toLowerCase();
  if (message.contains('cancel') || message.contains('denied')) {
    return 'Google sign-in was cancelled.';
  }
  if (message.contains('network') ||
      message.contains('socket') ||
      message.contains('connection')) {
    return 'Unable to connect. Check your internet connection and try again.';
  }
  return 'Google sign-in failed. Please try again.';
}

String _friendlyPasswordRecoveryError(AuthException error) {
  final message = error.message.toLowerCase();
  if (message.contains('network') ||
      message.contains('socket') ||
      message.contains('connection')) {
    return 'Unable to connect. Check your internet connection and try again.';
  }
  return 'Unable to send the reset link. Please try again later.';
}
