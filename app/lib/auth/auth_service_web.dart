import 'dart:developer' as developer;
import 'package:msal_js/msal_js.dart' as msal;

import 'auth_config.dart';
import 'auth_service.dart';

class AuthServiceWeb implements AuthService {
  final AuthConfig _config;

  bool _ready = false;
  bool _authed = false;
  bool _interactionInProgress = false;

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
    if (_interactionInProgress) {
      developer.log('Auth: Sign-in already in progress, ignoring');
      return;
    }

    _interactionInProgress = true;
    try {
      final result = await _pca.loginPopup(
        msal.PopupRequest()..scopes = _config.apiScopes,
      );
      if (result.account != null) {
        _pca.setActiveAccount(result.account!);
        _authed = true;
      } else {
        _authed = false;
      }
    } finally {
      _interactionInProgress = false;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _pca.logoutPopup();
    } catch (e) {
      developer.log('Auth: logoutPopup error: $e');
      // Force clear active account on error
      _pca.setActiveAccount(null);
    }
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
      final errorMsg = e.toString();

      // Check for errors that require interactive login
      if (errorMsg.contains('InteractionRequiredAuthError') ||
          errorMsg.contains('monitor_window_timeout') ||
          errorMsg.contains('AADSTS160021') ||
          errorMsg.contains('AADSTS50058') ||
          errorMsg.contains('no_account_error')) {
        // Prevent concurrent popup attempts
        if (_interactionInProgress) {
          developer.log('Auth: Popup already in progress, waiting...');
          return null;
        }

        try {
          developer.log('Auth: Silent token failed, trying popup...');
          _interactionInProgress = true;

          final res = await _pca.acquireTokenPopup(
            msal.PopupRequest()..scopes = scopes,
          );

          if (res.account != null) {
            _pca.setActiveAccount(res.account!);
          }

          return res.accessToken;
        } catch (e2) {
          final e2Msg = e2.toString();

          // Handle interaction_in_progress by waiting and retrying once
          if (e2Msg.contains('interaction_in_progress')) {
            developer.log('Auth: interaction_in_progress, clearing state...');
            // Wait a bit and let the other interaction complete
            await Future.delayed(const Duration(seconds: 2));
            _interactionInProgress = false;
            // Don't retry immediately, let the UI handle it
          } else {
            developer.log('Auth: acquireTokenPopup failed: $e2');
          }
          return null;
        } finally {
          _interactionInProgress = false;
        }
      }

      developer.log('Auth: acquireTokenSilent failed: $e');
      return null;
    }
  }
}

AuthService createAuthServiceImpl(AuthConfig config) => AuthServiceWeb(config);
