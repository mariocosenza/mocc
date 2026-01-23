import 'dart:js_interop';

@JS('APP_CONFIG.MOCC_API_URL')
external String? get _moccApiUrl;

/// Web implementation that reads from window.APP_CONFIG.MOCC_API_URL
String getApiUrlImpl() {
  final url = _moccApiUrl;
  if (url != null && url.isNotEmpty && !url.contains('%%')) {
    return url;
  }
  // Fallback to compile-time if placeholder was not replaced
  return const String.fromEnvironment(
    'MOCC_API_URL',
    defaultValue: 'http://localhost:80/query',
  );
}
