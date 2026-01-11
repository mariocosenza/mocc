abstract class AuthService {
  Future<void> init();

  bool get isReady;
  bool get isAuthenticated;

  Future<void> signIn();
  Future<void> signOut();

  Future<String?> acquireAccessToken({required List<String> scopes});
}
