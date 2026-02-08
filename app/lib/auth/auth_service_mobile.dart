import 'dart:developer' as developer;
import 'dart:io';
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
    try {
      final res = await _pca!.acquireToken(
        scopes: _config.apiScopes,
        prompt: Prompt.login,
      );
      _authed = res.accessToken.isNotEmpty;
    } on MsalException catch (e) {
      developer.log(
        'Mobile Auth SignIn Error: $e',
        name: 'AuthServiceMobile',
        error: e,
      );
      if (e.toString().contains('does not match')) {
        await _pca?.signOut();
      }
      _authed = false;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _pca!.signOut();
    } on MsalException catch (e) {
      if (e is MsalClientException && e.errorCode == 'no_current_account') {
        developer.log(
          'Ignored signOut error: no_current_account',
          name: 'AuthServiceMobile',
        );
      } else {
        rethrow;
      }
    }
    _authed = false;
  }

  @override
  Future<String?> acquireAccessToken({required List<String> scopes}) async {
    if (!_authed) return null;

    try {
      try {
        final res = await _pca!.acquireTokenSilent(scopes: scopes);
        return res.accessToken;
      } on MsalUiRequiredException {
        final res = await _pca!.acquireToken(scopes: scopes);
        return res.accessToken;
      }
    } on MsalException catch (e) {
      if (e is MsalClientException &&
          (e.errorCode == 'io_error' ||
              e.message.contains('Unable to resolve host'))) {
        throw SocketException(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<void> consent({required List<String> scopes}) async {
    await _pca!.acquireToken(scopes: scopes, prompt: Prompt.consent);
    // Refresh auth status
    final res = await _pca!.acquireTokenSilent(scopes: scopes);
    _authed = res.accessToken.isNotEmpty;
  }
}

AuthService createAuthServiceImpl(AuthConfig config) =>
    AuthServiceMobile(config);
