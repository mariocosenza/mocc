import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mocc/auth/auth_controller.dart';
import 'package:mocc/service/runtime_config.dart';
import 'package:signalr_netcore/signalr_client.dart';

final signalServiceProvider = Provider<SignalService>((ref) {
  final auth = ref.watch(authControllerProvider);
  return SignalService(ref, auth);
});

final signalRefreshProvider = StreamProvider<void>((ref) {
  final service = ref.read(signalServiceProvider);
  return service.refreshStream;
});

class SignalService {
  final Ref ref;
  final AuthController auth;
  HubConnection? _hubConnection;

  final _refreshController = StreamController<void>.broadcast();
  Stream<void> get refreshStream => _refreshController.stream;

  bool _isInitializing = false;

  String get _apimUrl {
    final baseUrl = getApiUrl();
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$cleanBase/signalr';
  }

  SignalService(this.ref, this.auth);

  Future<void> initialize(String userId) async {
    if (_hubConnection != null || _isInitializing) return;

    try {
      final token = await auth.token();
      if (token == null) {
        debugPrint('[SignalR] No access token available.');
        return;
      }

      _isInitializing = true;

      debugPrint('[SignalR] Initializing for user $userId...');

      // 1. Negotiate (Get URL)
      final url = await _negotiateWithRetry(userId, token);
      if (url == null) {
        debugPrint('[SignalR] Negotiation failed.');
        _isInitializing = false;
        return;
      }

      debugPrint('[SignalR] Connecting to $url');

      // 2. Connect
      _hubConnection = HubConnectionBuilder()
          .withUrl(url)
          .withAutomaticReconnect()
          .build();

      // Listen for specific events
      // We listen for 'refresh' for explicit refreshes, and 'newMessage' as a generic fallback
      _hubConnection?.on('refresh', _handleRefresh);
      _hubConnection?.on('newMessage', _handleMessage);

      await _hubConnection?.start();
      debugPrint('[SignalR] Connected!');
    } catch (e) {
      debugPrint('[SignalR] Initialization Error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<String?> _negotiateWithRetry(String userId, String token) async {
    int retries = 0;
    while (retries < 5) {
      try {
        final resp = await http.get(
          Uri.parse(_apimUrl),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          return data['url'];
        }

        // Cold start or error
        debugPrint(
          '[SignalR] Negotiate status: ${resp.statusCode}. Retrying...',
        );
      } catch (e) {
        debugPrint('[SignalR] Network error: $e');
      }

      retries++;
      await Future.delayed(Duration(seconds: 2 * retries));
    }
    return null;
  }

  void _handleRefresh(List<Object?>? args) {
    debugPrint('[SignalR] Refresh Signal Received');
    _refreshController.add(null);
  }

  void _handleMessage(List<Object?>? args) {
    // Check content
    debugPrint('[SignalR] Generic Message: $args');
    // Blindly trigger refresh for ANY message for now
    _refreshController.add(null);
  }

  void dispose() {
    _refreshController.close();
    _hubConnection?.stop();
  }
}
