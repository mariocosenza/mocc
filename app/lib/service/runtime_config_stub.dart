/// Stub implementation for non-web platforms.
/// Falls back to compile-time environment variable.
String getApiUrlImpl() {
  return const String.fromEnvironment(
    'MOCC_API_URL',
    defaultValue: 'http://localhost:80/query',
  );
}
