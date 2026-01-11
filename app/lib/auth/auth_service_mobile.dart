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
    } on MsalException {
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

AuthService createAuthServiceImpl() {
  throw StateError('Use AuthServiceMobile(AuthConfig) constructor via controller setup.');
}
