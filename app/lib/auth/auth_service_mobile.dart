import 'dart:developer' as developer;
import 'package:msal_auth/msal_auth.dart';

import 'auth_config.dart';
import 'auth_service.dart';

class AuthServiceMobile implements AuthService {
  final AuthConfig _config;

  bool _ready = false;
  bool _authed = false;

  SingleAccountPca? _pca;

  AuthServiceMobile(this._config);

  @override
  bool get isReady => _ready;

  @override
  bool get isAuthenticated => _authed;

  @override
  Future<void> init() async {
    _pca = await SingleAccountPca.create(
      clientId: _config.clientId,
      androidConfig: AndroidConfig(
        configFilePath: 'assets/msal_config.json',
        redirectUri: _config.redirectUriAndroid,
      ),
      appleConfig: AppleConfig(authorityType: AuthorityType.aad),
    );

    try {
      final res = await _pca!.acquireTokenSilent(scopes: _config.apiScopes);
      _authed = res.accessToken.isNotEmpty;
    } on MsalException catch (e) {
      developer.log(
        'Mobile Auth Init Error: $e',
        name: 'AuthServiceMobile',
        error: e,
      );
      // If the cached user is invalid (e.g. "sign in user does not match"), clear cache.
      if (e.toString().contains('does not match')) {
        await _pca?.signOut();
      }
      _authed = false;
    }

    _ready = true;
  }

  @override
  Future<void> signIn() async {
    final res = await _pca!.acquireToken(
      scopes: _config.apiScopes,
      prompt: Prompt.login,
    );
    _authed = res.accessToken.isNotEmpty;
  }

  @override
  Future<void> signOut() async {
    await _pca!.signOut();
    _authed = false;
  }

  @override
  Future<String?> acquireAccessToken({required List<String> scopes}) async {
    if (!_authed) return null;

    try {
      final res = await _pca!.acquireTokenSilent(scopes: scopes);
      return res.accessToken;
    } on MsalUiRequiredException {
      final res = await _pca!.acquireToken(scopes: scopes);
      return res.accessToken;
    }
  }
}

AuthService createAuthServiceImpl(AuthConfig config) =>
    AuthServiceMobile(config);
