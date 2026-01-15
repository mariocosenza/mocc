import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'auth_config.dart';
import 'auth_service.dart';
import 'auth_service_web.dart';
import 'auth_service_mobile.dart';

final authConfigProvider = Provider<AuthConfig>((ref) {

  const clientId = String.fromEnvironment('AUTH_CLIENT_ID');
  const authority = String.fromEnvironment('AUTH_AUTHORITY');
  const redirectUriWeb = String.fromEnvironment('AUTH_REDIRECT_URI_WEB');
  const redirectUriAndroid = String.fromEnvironment('AUTH_REDIRECT_URI_ANDROID');
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

  AuthController(this.config) {
    // Pick implementation at runtime using kIsWeb.
    // (This avoids factory limitations because constructors need config.)
    _service = kIsWeb ? AuthServiceWeb(config) : AuthServiceMobile(config);
  }

  bool get ready => _service.isReady;
  bool get isAuthenticated => _service.isAuthenticated;

  Future<void> init() async {
    await _service.init();
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

  Future<String?> token() => _service.acquireAccessToken(scopes: config.apiScopes);

  Future<String?> acquireAccessToken({required List<String> scopes}) {
    return _service.acquireAccessToken(scopes: scopes);
  }
}
