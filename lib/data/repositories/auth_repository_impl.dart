import '../../domain/repositories/auth_repository.dart';
import '../datasources/local_data_source.dart';

/// Implementation of AuthRepository using LocalDataSource.
class AuthRepositoryImpl implements AuthRepository {
  final LocalDataSource _localDataSource;

  AuthRepositoryImpl(this._localDataSource);

  @override
  Future<String?> getAccessToken() => _localDataSource.getAccessToken();

  @override
  Future<String?> getRefreshToken() => _localDataSource.getRefreshToken();

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) =>
      _localDataSource.saveTokens(accessToken, refreshToken);

  @override
  Future<void> clearTokens() => _localDataSource.clearTokens();

  @override
  Future<bool> isAuthenticated() => _localDataSource.hasTokens();

  @override
  Future<void> simulateLogin() async {
    // Simulate a login by saving demo tokens
    await saveTokens(
      'demo-access-token-${DateTime.now().millisecondsSinceEpoch}',
      'demo-refresh-token-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
