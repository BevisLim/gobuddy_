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
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('password')) {
        throw Exception(
          'Please choose a stronger password with at least 6 characters.',
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
    final pendingEmail =
        prefs.getString(Constants.registrationPendingEmailKey)?.toLowerCase();
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
          'Choose a stronger password with at least 6 characters.',
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

  Future<void> signInWithGoogle() async {
    try {
      // A pending email-link registration must never send a Google user to
      // the email-only Set Password flow.
      await setRegistrationPending(false);
      final launched = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : Constants.supabaseLoginCallback,
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
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return profile != null;
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

  Future<bool> isLogin() async {
    // TODO: fake data, remove this when integrating real auth
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(Constants.isLoginKey) ?? false;
    // END TODO

    // ignore: dead_code
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
    return 'Please choose a stronger password with at least 6 characters.';
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
