import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('APP_CONFIG')
external JSObject? get _appConfig;

/// Web implementation that reads from window.APP_CONFIG
String getApiUrlImpl() {
  return _getConfig('MOCC_API_URL') ??
      const String.fromEnvironment(
        'MOCC_API_URL',
        defaultValue: 'http://localhost:80/query',
      );
}

String getApiScopesImpl() {
  return _getConfig('AUTH_API_SCOPES') ??
      const String.fromEnvironment(
        'AUTH_API_SCOPES',
        defaultValue: 'api://mocc-backend-api/access_as_user',
      );
}

String getClientIdImpl() {
  return _getConfig('AUTH_CLIENT_ID') ??
      const String.fromEnvironment(
        'AUTH_CLIENT_ID',
        defaultValue: '1abbe04a-3b9b-4a19-800c-cd8cbbe479f4',
      );
}

String? _getConfig(String key) {
  final config = _appConfig;
  if (config != null) {
    final val = config.getProperty(key.toJS);
    if (val != null && val.isA<JSString>()) {
      final str = (val as JSString).toDart;
      if (str.isNotEmpty && !str.contains('%%')) {
        return str;
      }
    }
  }
  return null;
}
