import 'dart:async';
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
  Future<void> _tokenLock = Future.value();

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

    try {
      // handleRedirectFuture is essential on web to settle MSAL state after a redirect or on first load
      await _pca.handleRedirectFuture();
      developer.log(
        'Auth: handleRedirectFuture completed',
        name: 'AuthServiceWeb',
      );
    } catch (e) {
      developer.log(
        'Auth: handleRedirectFuture error: $e',
        name: 'AuthServiceWeb',
        error: e,
      );
    }

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
    if (account == null) {
      developer.log(
        'Auth: No active account, cannot acquire token',
        name: 'AuthServiceWeb',
      );
      return null;
    }

    // We use a Future chain as a simple mutex to prevent concurrent JS calls to MSAL
    final completer = Completer<String?>();

    _tokenLock = _tokenLock
        .then((_) async {
          try {
            final res = await _pca
                .acquireTokenSilent(
                  msal.SilentRequest()
                    ..scopes = scopes
                    ..account = account,
                )
                .timeout(const Duration(seconds: 180));

            completer.complete(res.accessToken);
          } catch (e) {
            developer.log(
              'Auth: acquireTokenSilent failed or timed out: $e',
              name: 'AuthServiceWeb',
              error: e,
            );

            // Fallback to interactive acquisition
            if (_interactionInProgress) {
              developer.log(
                'Auth: Interaction already in progress, aborting fallback popup',
                name: 'AuthServiceWeb',
              );
              if (!completer.isCompleted) completer.complete(null);
              return;
            }

            _interactionInProgress = true;
            try {
              developer.log(
                'Auth: Falling back to acquireTokenPopup',
                name: 'AuthServiceWeb',
              );
              final res = await _pca.acquireTokenPopup(
                msal.PopupRequest()
                  ..scopes = scopes
                  ..account = account,
              );
              if (!completer.isCompleted) completer.complete(res.accessToken);
            } catch (e2) {
              developer.log(
                'Auth: acquireTokenPopup error: $e2',
                name: 'AuthServiceWeb',
                error: e2,
              );
              if (!completer.isCompleted) completer.complete(null);
            } finally {
              _interactionInProgress = false;
            }
          }
        })
        .catchError((err) {
          developer.log(
            'Auth: Mutex chain error: $err',
            name: 'AuthServiceWeb',
          );
          if (!completer.isCompleted) completer.complete(null);
        });

    return completer.future;
  }

  @override
  Future<void> consent({required List<String> scopes}) async {
    if (_interactionInProgress) return;
    _interactionInProgress = true;
    try {
      final res = await _pca.acquireTokenPopup(
        msal.PopupRequest()..scopes = scopes,
      );
      if (res.account != null) {
        _pca.setActiveAccount(res.account!);
        _authed = true;
      }
    } finally {
      _interactionInProgress = false;
    }
  }
}

AuthService createAuthServiceImpl(AuthConfig config) => AuthServiceWeb(config);
