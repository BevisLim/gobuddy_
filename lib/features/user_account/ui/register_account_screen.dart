import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../authentication/ui/view_model/authentication_view_model.dart';

const _purple = Color(0xFF7C3AED);
const _ink = Color(0xFF281950);
const _lightPurple = Color(0xFFD5CFEF);
const _muted = Color(0xFF686082);

/// Email registration screen owned by the User Account module.
class RegisterAccountScreen extends ConsumerStatefulWidget {
  const RegisterAccountScreen({super.key});

  @override
  ConsumerState<RegisterAccountScreen> createState() =>
      _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends ConsumerState<RegisterAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _register() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    ref
        .read(authenticationViewModelProvider.notifier)
        .signInWithMagicLink(email);
    context.push(Routes.otp, extra: {'email': email, 'isRegister': true});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          surfaceTintColor: Colors.white,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height - 140,
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 40),
                      const Text('Create your account',
                          style: TextStyle(
                              color: _ink,
                              fontSize: 32,
                              height: 1.1,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 9),
                      const Text('Start planning meaningful journeys.',
                          style: TextStyle(color: _muted, fontSize: 15)),
                      const SizedBox(height: 34),
                      const Text('Email Address',
                          style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                        decoration: InputDecoration(
                          hintText: 'example@email.com',
                          hintStyle: const TextStyle(color: _muted),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          enabledBorder: _inputBorder,
                          focusedBorder: _inputBorder.copyWith(
                            borderSide: const BorderSide(
                                color: _purple, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _purple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Continue',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const Spacer(),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Already have an account? ',
                                style: TextStyle(color: _muted)),
                            TextButton(
                              onPressed: () => context.go(Routes.login),
                              style: TextButton.styleFrom(
                                foregroundColor: _purple,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Sign in',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
    return 'Enter a valid email address';
  }
  return null;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) => const Row(children: [
        DecoratedBox(
          decoration: BoxDecoration(color: _purple, shape: BoxShape.circle),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.explore_rounded, color: Colors.white, size: 21),
          ),
        ),
        SizedBox(width: 10),
        Text('GoBuddy',
            style: TextStyle(
                color: _ink, fontSize: 20, fontWeight: FontWeight.w800)),
      ]);
}

final _inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(14),
  borderSide: const BorderSide(color: _lightPurple),
);
