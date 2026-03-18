/// Repository interface for authentication operations.
abstract class AuthRepository {
  /// Gets the current access token.
  Future<String?> getAccessToken();

  /// Gets the current refresh token.
  Future<String?> getRefreshToken();

  /// Saves tokens after login/refresh.
  Future<void> saveTokens(String accessToken, String refreshToken);

  /// Clears all tokens (logout).
  Future<void> clearTokens();

  /// Checks if user is authenticated.
  Future<bool> isAuthenticated();

  /// Simulates a login for demo purposes.
  Future<void> simulateLogin();
}
