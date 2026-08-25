import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mvvm_riverpod/core/constants/constants.dart';
import 'package:flutter_mvvm_riverpod/core/environment/env.dart';
import 'package:flutter_mvvm_riverpod/generated/locale_keys.g.dart';
import 'package:flutter_mvvm_riverpod/features/common/remote/supabase_client.dart';

part 'authentication_repository.g.dart';

@riverpod
AuthenticationRepository authenticationRepository(Ref ref) {
  return AuthenticationRepository();
}

class AuthenticationRepository {
  const AuthenticationRepository();

  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static Future<void>? _googleSignInInitialization;

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

  Future<void> resetPassword(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      throw Exception(error.message);
    } catch (error) {
      throw Exception(LocaleKeys.unexpectedErrorOccurred.tr());
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    // TODO: fake data
    return AuthResponse(
      user: User(
        id: '',
        appMetadata: {},
        userMetadata: {},
        aud: '',
        createdAt: '',
        email: 'henry@google.com',
      ),
    );

    // ignore: dead_code
    try {
      const List<String> scopes = <String>[
        Constants.googleEmailScope,
        Constants.googleUserInfoScope,
      ];

      _googleSignInInitialization ??= _googleSignIn.initialize(
        clientId: Env.googleClientId,
        serverClientId: Env.googleServerClientId,
      );
      await _googleSignInInitialization;

      if (!_googleSignIn.supportsAuthenticate()) {
        throw UnsupportedError(
            'Google Sign-In is not supported on this platform.');
      }

      final googleUser = await _googleSignIn.authenticate(scopeHint: scopes);
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception(LocaleKeys.idTokenNotFound.tr());
      }

      final result = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return result;
    } on AuthException catch (error) {
      throw Exception(error.message);
    } catch (error) {
      throw Exception(LocaleKeys.unexpectedErrorOccurred.tr());
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
    // TODO: fake data
    await setIsLogin(false);
    return;

    // ignore: dead_code
    try {
      await supabase.auth.signOut();
      Purchases.logOut();
    } on AuthException catch (error) {
      throw Exception(error.message);
    } catch (error) {
      throw Exception(LocaleKeys.unexpectedErrorOccurred.tr());
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
