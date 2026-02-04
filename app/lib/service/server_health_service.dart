import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocc/auth/auth_controller.dart';
import 'dart:convert';
import 'package:mocc/service/runtime_config.dart';
import 'package:http/http.dart' as http;

enum ServerStatus { initial, checking, online, wakingUp, error }

// Using NotifierProvider for Riverpod 3.x compatibility
final serverHealthProvider =
    NotifierProvider<ServerHealthService, ServerStatus>(() {
      return ServerHealthService();
    });

class ServerHealthService extends Notifier<ServerStatus> {
  Timer? _retryTimer;
  int _attempts = 0;
  static const int _maxAttempts = 30;

  // READINESS LISTENABLE for GoRouter
  final ValueNotifier<bool> readyNotifier = ValueNotifier(false);

  @override
  ServerStatus build() {
    // Handle disposal of resources
    ref.onDispose(() {
      _retryTimer?.cancel();
      readyNotifier.dispose();
    });
    return ServerStatus.initial;
  }

  bool get isReady => state == ServerStatus.online;

  void startCheck() async {
    // Wait for auth to be fully ready before checking
    final auth = ref.read(authControllerProvider);
    if (!auth.ready) {
      await auth.initialized;
    }

    if (state == ServerStatus.online || state == ServerStatus.checking) {
      return;
    }
    _attempts = 0;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 10), _checkHealth);
  }

  void retry() {
    _attempts = 0;
    _checkHealth();
  }

  void reportError() {
    // Avoid resetting if already in error or waking up (which is a specific kind of error handling)
    if (state == ServerStatus.error || state == ServerStatus.wakingUp) return;
    
    if (state == ServerStatus.online) {
      debugPrint('[ServerHealth] External component reported error. Setting status to error.');
      _setStatus(ServerStatus.error);
      _scheduleRetry();
    }
  }

  Future<void> _checkHealth() async {
    // Access auth controller via ref
    final auth = ref.read(authControllerProvider);

    if (!auth.isAuthenticated) {
      _setStatus(ServerStatus.online);
      return;
    }

    _setStatus(ServerStatus.checking);

    try {
      final token = await auth.token();
      if (token == null) {
        _scheduleRetry();
        return;
      }

      final apiUrl = getApiUrl();
      debugPrint(
        '[ServerHealth] Checking GraphQL at $apiUrl (Attempt ${_attempts + 1})',
      );

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'query': '{ __typename }'}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[ServerHealth] Server is ONLINE (GraphQL check passed).');
        _setStatus(ServerStatus.online);
        _retryTimer?.cancel();
      } else {
        debugPrint(
          '[ServerHealth] Server returned ${response.statusCode}. Waking up...',
        );
        _scheduleRetry();
      }
    } catch (e) {
      debugPrint('[ServerHealth] Network error: $e');
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_attempts >= _maxAttempts) {
      _setStatus(ServerStatus.error);
      _attempts = 0;
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 5), _checkHealth);
      return;
    }

    _setStatus(ServerStatus.wakingUp);
    _attempts++;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), _checkHealth);
  }

  void _setStatus(ServerStatus newStatus) {
    if (state != newStatus) {
      state = newStatus;
      readyNotifier.value = (newStatus == ServerStatus.online);
    }
  }
}
