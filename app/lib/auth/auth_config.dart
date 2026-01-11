class AuthConfig {
  final String clientId;
  final String authority;          // https://login.microsoftonline.com/<TENANT_ID>
  final String redirectUriWeb;     // https://<your-swa>.azurestaticapps.net/
  final String redirectUriAndroid; // msauth://<package>/<signature>
  final List<String> apiScopes;    // e.g. ['api://.../access_as_user']

  const AuthConfig({
    required this.clientId,
    required this.authority,
    required this.redirectUriWeb,
    required this.redirectUriAndroid,
    required this.apiScopes,
  });
}
