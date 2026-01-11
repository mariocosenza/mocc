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
  const apiScopesRaw = String.fromEnvironment('AUTH_API_SCOPES', defaultValue: 'User.Read');
  
  final apiScopes = apiScopesRaw.split(',');

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
}
