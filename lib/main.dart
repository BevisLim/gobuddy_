import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mvvm_riverpod/core/environment/env.dart';
import 'package:flutter_mvvm_riverpod/core/notifications/push_notification_service.dart';
import 'package:flutter_mvvm_riverpod/core/routing/router.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_theme.dart';
import 'package:flutter_mvvm_riverpod/features/common/ui/providers/app_theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('vi')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const ProviderScope(child: GoBuddyApp()),
    ),
  );

  unawaited(PushNotificationService.initialize().catchError((error, stack) {
    debugPrint('Notification setup failed: $error');
  }));
}

class GoBuddyApp extends ConsumerWidget {
  const GoBuddyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(appThemeModeProvider).value ?? ThemeMode.system;
    return MaterialApp.router(
      title: 'GoBuddy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.materialTheme,
      darkTheme: AppTheme.darkMaterialTheme,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
