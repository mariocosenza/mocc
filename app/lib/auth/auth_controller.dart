import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'auth_config.dart';
import 'auth_service.dart';
import 'auth_service_factory.dart';

final authConfigProvider = Provider<AuthConfig>((ref) {
  const clientId = String.fromEnvironment('AUTH_CLIENT_ID');
  const authority = String.fromEnvironment('AUTH_AUTHORITY');

  String redirectUriWeb = const String.fromEnvironment('AUTH_REDIRECT_URI_WEB');
  if (redirectUriWeb.isEmpty && kIsWeb) {
    // Dynamically use the current origin (e.g., http://localhost:8080 or https://xxx.azurestaticapps.net)
    redirectUriWeb = '${Uri.base.origin}/';
  }

  const redirectUriAndroid = String.fromEnvironment(
    'AUTH_REDIRECT_URI_ANDROID',
  );
  const apiScopesRaw = String.fromEnvironment('AUTH_API_SCOPES');

  final apiScopes = apiScopesRaw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (apiScopes.isEmpty) {
    throw StateError(
      'AUTH_API_SCOPES is not set. Use the backend API scope, e.g. '
      'api://<backend-app-id>/access_as_user',
    );
  }

  final hasGraphScope = apiScopes.any(
    (s) => s == 'User.Read' || s.startsWith('https://graph.microsoft.com/'),
  );
  if (hasGraphScope) {
    throw StateError(
      'AUTH_API_SCOPES is pointing to Microsoft Graph. '
      'Set it to your backend API scope, e.g. api://<backend-app-id>/access_as_user.',
    );
  }

  return AuthConfig(
    clientId: clientId,
    authority: authority,
    redirectUriWeb: redirectUriWeb,
    redirectUriAndroid: redirectUriAndroid,
    apiScopes: apiScopes,
  );
});

final authControllerProvider = Provider<AuthController>((ref) {
  final config = ref.watch(authConfigProvider);
  return AuthController(config)..init();
});

class AuthController extends ChangeNotifier {
  final AuthConfig config;
  late final AuthService _service;

  final Completer<void> _initCompleter = Completer<void>();

  /// Future that completes when auth service is initialized
  Future<void> get initialized => _initCompleter.future;

  AuthController(this.config) {
    _service = createAuthService(config);
  }

  bool get ready => _service.isReady;
  bool get isAuthenticated => _service.isAuthenticated;

  Future<void> init() async {
    try {
      await _service.init();
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } catch (e) {
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    await _service.signIn();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _service.signOut();
    notifyListeners();
  }

  /// Gets token, waiting for initialization if needed
  Future<String?> token() async {
    await _initCompleter.future; // Wait for init to complete
    return _service.acquireAccessToken(scopes: config.apiScopes);
  }

  Future<String?> acquireAccessToken({required List<String> scopes}) async {
    await _initCompleter.future; // Wait for init to complete
    return _service.acquireAccessToken(scopes: scopes);
  }

  Future<void> consent({required List<String> scopes}) async {
    await _initCompleter.future;
    return _service.consent(scopes: scopes);
  }
}
