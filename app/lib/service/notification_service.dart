import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import 'user_service.dart';
import 'package:mocc/router/router.dart';

class NotificationService {
  final UserService _userService;

  NotificationService(this._userService);

  Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _setupNotificationTapHandlers();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _registerDevice(token);
      }

      messaging.onTokenRefresh.listen((newToken) {
        _registerDevice(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        if (message.notification != null) {
          debugPrint(
            'Notification: ${message.notification!.title} - ${message.notification!.body}',
          );
        }
      });
    }
  }

  Future<void> refreshRegistration() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    if (token != null) {
      debugPrint('Refreshing FCM Registration with token: $token');
      await _registerDevice(token);
    }
  }

  Future<void> _setupNotificationTapHandlers() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = (message.data['route'] ?? message.data['deep_link'])
        ?.toString()
        .trim();

    _safeNavigate(route == null || route.isEmpty ? '/app/home' : route);
  }

  void _safeNavigate(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) {
        debugPrint(
          '[DEVLOG] NotificationService: navigator context not ready for route=$route',
        );
        return;
      }

      try {
        GoRouter.of(ctx).go(route);
      } catch (e) {
        debugPrint('[DEVLOG] NotificationService: navigation error: $e');
      }
    });
  }

  Future<void> _registerDevice(String token) async {
    try {
      if (kIsWeb) {
        return;
      }

      final platform = Platform.isIOS ? 'apns' : 'fcm';
      debugPrint(
        '[DEVLOG] NotificationService: calling registerDevice with token=$token, platform=$platform',
      );

      await _userService.registerDevice(token, platform);

      debugPrint(
        '[DEVLOG] NotificationService: Device registered successfully.',
      );
    } catch (e) {
      debugPrint('[DEVLOG] NotificationService: Error registering device: $e');
    }
  }
}
