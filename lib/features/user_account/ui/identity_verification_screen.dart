import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mvvm_riverpod/core/extensions/build_context_extension.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_colors.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_theme.dart';
import 'view_model/user_account_view_model.dart';

enum _DocumentType { nationalId, passport, driversLicense }

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  int _step = 0;
  _DocumentType? _documentType;
  bool _frontCaptured = false;
  bool _backCaptured = false;
  bool _selfieVerified = false;

  bool get _canContinue => switch (_step) {
        0 => _documentType != null,
        1 => _frontCaptured,
        2 => _backCaptured,
        _ => _selfieVerified,
      };

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(userAccountViewModelProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.brandBackground,
      appBar: AppBar(
        leading: BackButton(onPressed: isSubmitting ? null : _goBack),
        title: Text('Identity Verification', style: AppTheme.title20),
        backgroundColor: AppColors.brandBackground,
        foregroundColor: AppColors.brandPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: _VerificationProgress(currentStep: _step),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _stepContent(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: !_canContinue || isSubmitting
                      ? null
                      : _step == 3
                          ? _submit
                          : () => setState(() => _step++),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandSurface,
                    foregroundColor: AppColors.brandBackground,
                    disabledBackgroundColor: AppColors.brandBorder,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.brandBackground,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _step == 3 ? 'Submit Verification' : 'Next Step',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepContent() {
    return switch (_step) {
      0 => _DocumentTypeStep(
          selected: _documentType,
          onSelected: (value) => setState(() => _documentType = value),
        ),
      1 => _CaptureStep(
          title: 'Front of document',
          description: 'Position your ID clearly within the frame.',
          icon: Icons.badge_outlined,
          completed: _frontCaptured,
          actionLabel: 'Tap to capture/upload front document',
          onCapture: () => setState(() => _frontCaptured = true),
        ),
      2 => _CaptureStep(
          title: 'Back of document',
          description: 'Make sure all details are visible and in focus.',
          icon: Icons.credit_card_outlined,
          completed: _backCaptured,
          actionLabel: 'Tap to capture/upload back document',
          onCapture: () => setState(() => _backCaptured = true),
        ),
      _ => _CaptureStep(
          title: 'Take a selfie',
          description: 'Make sure your face is clearly visible.',
          icon: Icons.face_retouching_natural_outlined,
          completed: _selfieVerified,
          completedLabel: 'Face verified',
          actionLabel: 'Tap to complete mock selfie check',
          onCapture: () => setState(() => _selfieVerified = true),
        ),
    };
  }

  void _goBack() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _submit() async {
    final success = await ref
        .read(userAccountViewModelProvider.notifier)
        .completeIdentityVerification();
    if (!mounted) return;

    if (success) {
      context.showSuccessSnackBar('Identity verified successfully.');
      context.pop();
    } else {
      final error = ref.read(userAccountViewModelProvider).error;
      context.showErrorSnackBar(error ?? 'Unable to verify identity.');
    }
  }
}

class _VerificationProgress extends StatelessWidget {
  const _VerificationProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Document', 'Front ID', 'Back ID', 'Selfie'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= currentStep;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.brandSurface
                            : AppColors.brandBackground,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active
                              ? AppColors.brandSurface
                              : AppColors.brandBorder,
                        ),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: AppTheme.title12.copyWith(
                          color: active
                              ? AppColors.brandBackground
                              : AppColors.brandTextMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body12.copyWith(
                        color: active
                            ? AppColors.brandPrimary
                            : AppColors.brandTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < labels.length - 1)
                Container(
                  width: 12,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 24),
                  color: index < currentStep
                      ? AppColors.brandSurface
                      : AppColors.brandBorder,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _DocumentTypeStep extends StatelessWidget {
  const _DocumentTypeStep({
    required this.selected,
    required this.onSelected,
  });

  final _DocumentType? selected;
  final ValueChanged<_DocumentType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identity Verification',
          style: AppTheme.title32.copyWith(color: AppColors.brandPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Verify your identity to unlock all features.',
          style: AppTheme.body16.copyWith(
            color: AppColors.brandTextMuted,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'SELECT DOCUMENT TYPE',
          style: AppTheme.title12.copyWith(
            color: AppColors.brandTextMuted,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: 12),
        _DocumentOption(
          title: 'National ID',
          icon: Icons.badge_outlined,
          selected: selected == _DocumentType.nationalId,
          onTap: () => onSelected(_DocumentType.nationalId),
        ),
        const SizedBox(height: 12),
        _DocumentOption(
          title: 'Passport',
          icon: Icons.menu_book_outlined,
          selected: selected == _DocumentType.passport,
          onTap: () => onSelected(_DocumentType.passport),
        ),
        const SizedBox(height: 12),
        _DocumentOption(
          title: "Driver's License",
          icon: Icons.directions_car_outlined,
          selected: selected == _DocumentType.driversLicense,
          onTap: () => onSelected(_DocumentType.driversLicense),
        ),
      ],
    );
  }
}

class _DocumentOption extends StatelessWidget {
  const _DocumentOption({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandBorder.withValues(alpha: .35)
              : AppColors.brandBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.brandSurface : AppColors.brandBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.brandSurface, size: 28),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: AppTheme.title16)),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color:
                  selected ? AppColors.brandSurface : AppColors.brandTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureStep extends StatelessWidget {
  const _CaptureStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.completed,
    required this.actionLabel,
    required this.onCapture,
    this.completedLabel = 'Document captured',
  });

  final String title;
  final String description;
  final IconData icon;
  final bool completed;
  final String actionLabel;
  final String completedLabel;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTheme.title32.copyWith(color: AppColors.brandPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: AppTheme.body16.copyWith(color: AppColors.brandTextMuted),
        ),
        const SizedBox(height: 32),
        InkWell(
          onTap: onCapture,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.brandBorder.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    completed ? AppColors.brandSurface : AppColors.brandBorder,
                width: completed ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  completed ? Icons.verified_rounded : icon,
                  color: AppColors.brandSurface,
                  size: 64,
                ),
                const SizedBox(height: 20),
                Text(
                  completed ? completedLabel : actionLabel,
                  textAlign: TextAlign.center,
                  style: AppTheme.title16.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  completed
                      ? 'Tap again to replace this mock capture.'
                      : 'Camera and OCR integration will be added later.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body14.copyWith(
                    color: AppColors.brandTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
