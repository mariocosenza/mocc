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

  void startCheck() {
    if (state == ServerStatus.online || state == ServerStatus.checking) {
      return;
    }
    _attempts = 0;
    _checkHealth();
  }

  void retry() {
    _attempts = 0;
    _checkHealth();
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
        _setStatus(ServerStatus.error);
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
      return;
    }

    _setStatus(ServerStatus.wakingUp);
    _attempts++;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), _checkHealth);
  }

  void _setStatus(ServerStatus newStatus) {
    if (state != newStatus) {
      state = newStatus;
      readyNotifier.value = (newStatus == ServerStatus.online);
    }
  }
}
