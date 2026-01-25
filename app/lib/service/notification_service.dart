import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'user_service.dart';

class NotificationService {
  final UserService _userService;

  NotificationService(this._userService);

  Future<void> initialize() async {
    // 1. Request permissions
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // 2. Get Token
      String? token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _registerDevice(token);
      }

      // 3. Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _registerDevice(newToken);
      });

      // 4. Foreground handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');

        if (message.notification != null) {
          debugPrint(
            'Notification: ${message.notification?.title} - ${message.notification?.body}',
          );
        }
      });
    }
  }

  Future<void> _registerDevice(String token) async {
    try {
      if (kIsWeb) {
        return; // Notification Hubs via direct API is simpler without web (VAPID) complexity for now.
      }

      final platform = Platform.isIOS ? 'apns' : 'fcm';
      // UserService needs to expose the mutation or generic client access
      await _userService.registerDevice(token, platform);

      debugPrint('Device registered with Notification Hubs via Backend');
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }
}
