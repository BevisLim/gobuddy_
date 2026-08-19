import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_mvvm_riverpod/core/constants/constants.dart';
import 'package:flutter_mvvm_riverpod/core/extensions/build_context_extension.dart';
import '../../../../generated/locale_keys.g.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_colors.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_theme.dart';
import '../view_model/premium_view_model.dart';

class PremiumFooter extends ConsumerWidget {
  const PremiumFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.tryLaunchUrl(Constants.termsOfService),
          child: Text(
            LocaleKeys.terms.tr(),
            style: AppTheme.title12.copyWith(color: AppColors.mono0),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "|",
            style: AppTheme.body12.copyWith(color: AppColors.mono0),
          ),
        ),
        TextButton(
          onPressed: () =>
              ref.read(premiumViewModelProvider.notifier).restorePurchases(),
          child: Text(
            LocaleKeys.restorePurchases.tr(),
            style: AppTheme.title12.copyWith(color: AppColors.mono0),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "|",
            style: AppTheme.body12.copyWith(color: AppColors.mono0),
          ),
        ),
        TextButton(
          onPressed: () => context.tryLaunchUrl(Constants.privacyPolicy),
          child: Text(
            LocaleKeys.policy.tr(),
            style: AppTheme.title12.copyWith(color: AppColors.mono0),
          ),
        ),
      ],
    );
  }
}
