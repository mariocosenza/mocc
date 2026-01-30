import 'runtime_config_stub.dart'
    if (dart.library.js_interop) 'runtime_config_web.dart';

/// Returns the API URL from runtime configuration (web) or compile-time environment (native).
/// Returns the API URL from runtime configuration (web) or compile-time environment (native).
String getApiUrl() => getApiUrlImpl();

/// Returns the API Scopes from runtime configuration (web) or compile-time environment (native).
String getApiScopes() => getApiScopesImpl();
