import 'package:msal_js/msal_js.dart' as msal;

import 'auth_config.dart';
import 'auth_service.dart';

class AuthServiceWeb implements AuthService {
  final AuthConfig _config;

  bool _ready = false;
  bool _authed = false;

  late final msal.PublicClientApplication _pca;

  AuthServiceWeb(this._config);

  @override
  bool get isReady => _ready;

  @override
  bool get isAuthenticated => _authed;

  @override
  Future<void> init() async {
    _pca = msal.PublicClientApplication(
      msal.Configuration()
        ..auth = (msal.BrowserAuthOptions()
          ..clientId = _config.clientId
          ..authority = _config.authority
          ..redirectUri = _config.redirectUriWeb)
        ..cache = (msal.CacheOptions()
          ..cacheLocation = msal.BrowserCacheLocation.localStorage),
    );

    final accounts = _pca.getAllAccounts();
    if (accounts.isNotEmpty) {
      _pca.setActiveAccount(accounts.first);
      _authed = true;
    } else {
      _authed = false;
    }

    _ready = true;
  }

  @override
  Future<void> signIn() async {
    final result = await _pca.loginPopup(
      msal.PopupRequest()..scopes = _config.apiScopes,
    );
    if (result.account != null) {
      _pca.setActiveAccount(result.account!);
      _authed = true;
    } else {
      _authed = false;
    }
  }

  @override
  Future<void> signOut() async {
    await _pca.logoutPopup();
    _authed = false;
  }

  @override
  Future<String?> acquireAccessToken({required List<String> scopes}) async {
    if (!_authed) return null;

    final account = _pca.getActiveAccount();
    if (account == null) return null;

    try {
      final res = await _pca.acquireTokenSilent(
        msal.SilentRequest()
          ..scopes = scopes
          ..account = account,
      );

      return res.accessToken;
    } catch (e) {
      // ignore: avoid_print
      print('Core Error: acquireAccessToken failed: $e');
      return null;
    }
  }
}

AuthService createAuthServiceImpl(AuthConfig config) => AuthServiceWeb(config);
