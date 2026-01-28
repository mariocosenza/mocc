import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'user_service.dart';

class NotificationService {
  final UserService _userService;

  NotificationService(this._userService);

  Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 1. Request permissions
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // 2. Enable foreground notifications - show them like background notifications
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true, // Show the notification alert
        badge: true, // Update app badge
        sound: true, // Play sound
      );

      // 3. Get Token
      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _registerDevice(token);
      }

      // 4. Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _registerDevice(newToken);
      });

      // 5. Log foreground messages (optional - notifications will show automatically now)
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
