import 'package:apix/apix.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Centralized API client configuration.
///
/// Provides a single point of configuration for:
/// - Base URL
/// - Authentication with automatic token refresh
/// - Logging
/// - Error tracking
/// - Cache strategies
class ApiClientProvider {
  ApiClientProvider({required this.baseUrl});

  final String baseUrl;

  /// Token provider for secure storage
  late final SecureTokenProvider tokenProvider = SecureTokenProvider();

  /// Cache configuration
  late final _cacheConfig = CacheConfig(
    strategy: CacheStrategy.networkFirst,
    defaultTtl: const Duration(minutes: 5),
  );

  /// Cache interceptor for direct cache operations
  late final CacheInterceptor cacheInterceptor = CacheInterceptor(
    config: _cacheConfig,
  );

  /// Auth configuration with automatic refresh
  late final AuthConfig _authConfig = AuthConfig(
    tokenProvider: tokenProvider,
    refreshEndpoint: '/auth/refresh',
    onTokenRefreshed: (response) async {
      final json = response.data;
      final data = json is Map<String, dynamic> ? json : <String, dynamic>{};

      final accessToken = (data['access_token'] ?? '').toString();
      final refreshToken =
          (data['refresh_token'] ?? await tokenProvider.getRefreshToken())
              .toString();

      if (accessToken.isNotEmpty) {
        await tokenProvider.saveTokens(accessToken, refreshToken);
      }
    },
  );

  /// Configured API client with all interceptors
  late final client = ApiClientFactory.create(
    baseUrl: baseUrl,
    authConfig: _authConfig,
    retryConfig: const RetryConfig(
      maxAttempts: 3,
      retryStatusCodes: [500, 502, 503, 504],
    ),
    cacheConfig: _cacheConfig,
    loggerConfig: const LoggerConfig(
      level: kDebugMode ? LogLevel.info : LogLevel.error,
      redactedHeaders: ['Authorization'],
    ),
    errorTrackingConfig: ErrorTrackingConfig(
      onError: (exception, {stackTrace, extra, tags}) async {
        debugPrint('API Error: $exception');
        // Sentry integration example:
        await Sentry.captureException(exception, stackTrace: stackTrace);
      },
    ),
  );
}
