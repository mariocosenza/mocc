/// Stub implementation for non-web platforms.
/// Falls back to compile-time environment variable.
String getApiUrlImpl() {
  return const String.fromEnvironment(
    'MOCC_API_URL',
    defaultValue: 'http://localhost:8080/query',
  );
}

String getApiScopesImpl() {
  return const String.fromEnvironment(
    'AUTH_API_SCOPES',
    defaultValue: 'api://mocc-backend-api/access_as_user',
  );
}
