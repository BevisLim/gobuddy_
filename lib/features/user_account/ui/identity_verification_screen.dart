import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_mvvm_riverpod/core/extensions/build_context_extension.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_colors.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_theme.dart';
import 'package:flutter_mvvm_riverpod/core/routing/routes.dart';
import 'view_model/user_account_view_model.dart';

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key, this.fromOnboarding = false});

  final bool fromOnboarding;

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  bool _didOpenVerification = false;

  @override
  Widget build(BuildContext context) {
    final isStarting = ref.watch(userAccountViewModelProvider).isLoading;

    return PopScope(
      canPop: !widget.fromOnboarding,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.fromOnboarding && !isStarting) {
          context.go(Routes.main);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.brandBackground,
        appBar: AppBar(
          leading: BackButton(
            onPressed: isStarting
                ? null
                : () => widget.fromOnboarding
                    ? context.go(Routes.main)
                    : Navigator.maybePop(context),
          ),
          title: Text('Identity Verification', style: AppTheme.title20),
          backgroundColor: AppColors.brandBackground,
          foregroundColor: AppColors.brandPrimary,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: AppColors.brandBorder.withValues(alpha: .3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.brandSurface,
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _didOpenVerification
                            ? 'Verification started'
                            : 'Verify your identity',
                        textAlign: TextAlign.center,
                        style: AppTheme.title32.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _didOpenVerification
                            ? 'Complete the verification in the Didit page. '
                                'Your status will update after it is reviewed.'
                            : 'You will continue to Didit to securely verify '
                                'your identity document and face.',
                        textAlign: TextAlign.center,
                        style: AppTheme.body16.copyWith(
                          color: AppColors.brandTextMuted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const _VerificationDetailsCard(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                  onPressed: isStarting ? null : _startVerification,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandSurface,
                    foregroundColor: AppColors.brandBackground,
                    disabledBackgroundColor: AppColors.brandBorder,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isStarting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                color: AppColors.brandBackground,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Starting verification...',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        )
                      : Text(
                          _didOpenVerification
                              ? 'Open Verification Again'
                              : 'Verify Identity',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startVerification() async {
    final verificationUrl = await ref
        .read(userAccountViewModelProvider.notifier)
        .startIdentityVerification();
    if (!mounted) return;

    if (verificationUrl == null) {
      final message = ref.read(userAccountViewModelProvider).error;
      context.showErrorSnackBar(
        message ?? 'Unable to start identity verification. Please try again.',
      );
      return;
    }

    try {
      final launched = await launchUrl(
        Uri.parse(verificationUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const FormatException('The verification URL could not be opened.');
      }
      if (mounted) setState(() => _didOpenVerification = true);
    } catch (error, stackTrace) {
      debugPrint('Unable to open Didit verification URL: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        context.showErrorSnackBar(
          'Unable to open identity verification. Please try again.',
        );
      }
    }
  }
}

class _VerificationDetailsCard extends StatelessWidget {
  const _VerificationDetailsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandBorder.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.brandBorder),
      ),
      child: const Column(
        children: [
          _VerificationDetail(
            icon: Icons.badge_outlined,
            title: 'Identity document',
            description: 'Didit will guide you through document capture.',
          ),
          Divider(height: 32, color: AppColors.brandBorder),
          _VerificationDetail(
            icon: Icons.face_retouching_natural_outlined,
            title: 'Face and liveness check',
            description: 'Complete the secure face checks in Didit.',
          ),
          Divider(height: 32, color: AppColors.brandBorder),
          _VerificationDetail(
            icon: Icons.lock_outline_rounded,
            title: 'Secure verification',
            description: 'Verification is handled on Didit’s hosted page.',
          ),
        ],
      ),
    );
  }
}

class _VerificationDetail extends StatelessWidget {
  const _VerificationDetail({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.brandSurface, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTheme.title16),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTheme.body14.copyWith(
                  color: AppColors.brandTextMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
