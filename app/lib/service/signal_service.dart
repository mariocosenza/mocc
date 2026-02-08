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
  final service = SignalService(ref, auth);
  ref.onDispose(service.dispose);
  return service;
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
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return '$url?signalr=1';
  }

  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;
  bool get isInitializing => _isInitializing;
  Future<void>? _initializationFuture;

  SignalService(this.ref, this.auth);

  Future<void> initialize(String userId) async {
    if (isConnected) return;
    
    // Avoid race conditions: if already initializing, await the existing future
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    _initializationFuture = _initializeInternal(userId);
    await _initializationFuture;
    _initializationFuture = null;
  }

  Future<void> _initializeInternal(String userId) async {
    if (isConnected || _isInitializing) return;
    _isInitializing = true;

    try {
      final token = await auth.token();
      if (token == null) {
        debugPrint('[SignalR] No access token available.');
        return;
      }

      _isInitializing = true;
      debugPrint('[SignalR] Initializing for user $userId...');

      final connectionInfo = await _negotiateWithRetry(userId, token);
      
      if (connectionInfo == null) {
        debugPrint('[SignalR] Negotiation failed.');
        _isInitializing = false;
        return;
      }

      final signalrUrl = connectionInfo['url'] as String;
      final signalrAccessToken = connectionInfo['accessToken'] as String;

      debugPrint('[SignalR] Connecting via: $signalrUrl');


      _hubConnection = HubConnectionBuilder()
          .withUrl(
            signalrUrl,
            options: HttpConnectionOptions( 
              accessTokenFactory: () async => signalrAccessToken, 
            ),
          )
          .withAutomaticReconnect()
          .build();

      _hubConnection?.on('newRecipe', _handleNewRecipe);

      await _hubConnection?.start();
      debugPrint('[SignalR] Connected successfully!');
      
    } catch (e) {
      debugPrint('[SignalR] Initialization Error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<Map<String, dynamic>?> _negotiateWithRetry(String userId, String apiToken) async {
    int retries = 0;
    const maxRetries = 5;
    
    while (retries < maxRetries) {
      try {
        final resp = await http.post(
          Uri.parse(_apimUrl),
          headers: {'Authorization': 'Bearer $apiToken'},
        );

        if (resp.statusCode == 200) {
          return json.decode(resp.body) as Map<String, dynamic>;
        }

        // Handle 401/403: Do not retry
        if (resp.statusCode == 401 || resp.statusCode == 403) {
           debugPrint('[SignalR] Negotiate auth failed: ${resp.statusCode}');
           return null;
        }

        debugPrint(
          '[SignalR] Negotiate failed (Attempt ${retries + 1}). Status: ${resp.statusCode}, Body: ${resp.body}',
        );
      } catch (e) {
        debugPrint('[SignalR] Network error during negotiation: $e');
      }

      retries++;
      if (retries < maxRetries) {
        // Base delay: 2 seconds.
        // Delay = 2 * (retries) + jitter.
        final delaySeconds = (2 * retries) + (DateTime.now().millisecond % 1000) / 1000.0;
        await Future.delayed(Duration(milliseconds: (delaySeconds * 1000).toInt()));
      }
    }
    return null;
  }

  void _handleNewRecipe(List<Object?>? args) {
    debugPrint('[SignalR] Event "newRecipe" received: $args');
    
    if (args != null && args.isNotEmpty) {
      try {
        final data = args[0]; 
        
        if (data is Map) {
          if (data['type'] == 'refresh') {
             debugPrint('[SignalR] Refresh trigger confirmed.');
            _refreshController.add(null);
          } else {
             debugPrint('[SignalR] Ignored message type: ${data['type']}');
          }
        } else {
           debugPrint('[SignalR] Ignored invalid data format: $data');
        }
      } catch (e) {
        debugPrint('[SignalR] Error parsing message: $e');
      }
    } else {
      debugPrint('[SignalR] Received empty args list.');
    }
  }

  void triggerRefresh() {
    _refreshController.add(null);
  }

  void dispose() {
    _refreshController.close();
    _hubConnection?.stop();
  }
}