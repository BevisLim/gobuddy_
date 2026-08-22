import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_mvvm_riverpod/core/routing/router.dart';
import 'package:flutter_mvvm_riverpod/core/routing/routes.dart';
import 'package:flutter_mvvm_riverpod/features/common/remote/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<AuthState>? _authSubscription;
  static bool _initialized = false;

  static bool get _isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    if (_initialized || !_isSupported) return;
    _initialized = true;

    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) =>
          _openTrip(response.payload),
    );

    const channel = AndroidNotificationChannel(
      'gobuddy_updates',
      'GoBuddy updates',
      description: 'Join requests and collaboration updates',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_openRemoteMessage);
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Future<void>.delayed(const Duration(milliseconds: 500),
          () => _openRemoteMessage(initialMessage));
    }

    _tokenSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    _authSubscription = supabase.auth.onAuthStateChange.listen((event) {
      if (event.session != null) unawaited(_registerCurrentToken());
    });
    await _registerCurrentToken();
  }

  static Future<void> _registerCurrentToken() async {
    if (supabase.auth.currentUser == null) return;
    if (Platform.isIOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      Future<void>.delayed(const Duration(seconds: 2), _registerCurrentToken);
      return;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);
  }

  static Future<void> _registerToken(String token) async {
    if (supabase.auth.currentUser == null) return;
    await supabase.rpc('register_push_device', params: {
      'p_token': token,
      'p_platform': Platform.isIOS ? 'ios' : 'android',
    });
  }

  static Future<void> unregisterCurrentDevice() async {
    if (!_isSupported || supabase.auth.currentUser == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await supabase.rpc('unregister_push_device', params: {'p_token': token});
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'gobuddy_updates',
          'GoBuddy updates',
          channelDescription: 'Join requests and collaboration updates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['trip_id'] as String?,
    );
  }

  static void _openRemoteMessage(RemoteMessage message) =>
      _openTrip(message.data['trip_id'] as String?);

  static void _openTrip(String? tripId) {
    if (tripId == null || tripId.isEmpty) return;
    router.go('${Routes.groupCollaboration}?tripId=$tripId');
  }

  static Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
  }
}
