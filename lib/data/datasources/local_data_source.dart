import 'package:apix/apix.dart';

/// Local data source for token and secret storage using apix's SecureTokenProvider.
///
/// This class wraps [SecureTokenProvider] and provides additional convenience
/// methods for app-specific storage needs.
class LocalDataSource {
  final SecureTokenProvider _tokenProvider;

  /// Creates a [LocalDataSource] with optional custom [SecureStorageService].
  ///
  /// If no storage is provided, [SecureTokenProvider] creates one with
  /// secure defaults (encrypted shared preferences on Android, Keychain on iOS).
  LocalDataSource({SecureStorageService? storage})
    : _tokenProvider = SecureTokenProvider(storage: storage);

  /// Access to the underlying [SecureTokenProvider] for auth configuration.
  SecureTokenProvider get tokenProvider => _tokenProvider;

  /// Access to the underlying [SecureStorageService] for additional secrets.
  SecureStorageService get storage => _tokenProvider.storage;

  // ============================================================
  // TOKEN PROVIDER DELEGATE METHODS
  // ============================================================

  Future<String?> getAccessToken() => _tokenProvider.getAccessToken();

  Future<String?> getRefreshToken() => _tokenProvider.getRefreshToken();

  Future<void> saveTokens(String accessToken, String refreshToken) =>
      _tokenProvider.saveTokens(accessToken, refreshToken);

  Future<void> clearTokens() => _tokenProvider.clearTokens();

  Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ============================================================
  // ADDITIONAL STORAGE METHODS
  // ============================================================

  /// Store additional secrets (e.g., Firebase token, API keys).
  Future<void> writeSecret(String key, String value) =>
      storage.write(key, value);

  /// Read additional secrets.
  Future<String?> readSecret(String key) => storage.read(key);

  /// Delete a specific secret.
  Future<void> deleteSecret(String key) => storage.delete(key);
}
