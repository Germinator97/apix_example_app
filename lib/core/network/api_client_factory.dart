import 'package:apix/apix.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../data/datasources/local_data_source.dart';

/// Factory for creating a fully configured ApiClient with all interceptors.
class AppApiClientFactory {
  final LocalDataSource _localDataSource;

  AppApiClientFactory(this._localDataSource);

  /// Creates the ApiClient with all apix interceptors configured.
  ({ApiClient client, CacheInterceptor cacheInterceptor}) create() {
    // 1. Create base client
    final client = ApiClientFactory.create(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'X-App-Version': '1.0.0', 'Accept': 'application/json'},
    );

    // 2. Auth Interceptor - Using SecureTokenProvider with simplified refresh
    final tokenProvider = _localDataSource.tokenProvider;
    final authInterceptor = AuthInterceptor(
      AuthConfig(
        tokenProvider: tokenProvider,
        headerName: 'Authorization',
        headerPrefix: 'Bearer',
        refreshStatusCodes: [401],
        // Simplified refresh flow (NEW in v0.3)
        refreshEndpoint: '/auth/refresh',
        onTokenRefreshed: (response) async {
          // Parse response and save new tokens
          final data = response.data as Map<String, dynamic>?;
          if (data != null) {
            await tokenProvider.saveTokens(
              data['access_token'] as String? ?? '',
              data['refresh_token'] as String? ?? '',
            );
          }
        },
      ),
      client.dio,
    );

    // 3. Retry Interceptor - Automatic retries with backoff
    final retryInterceptor = RetryInterceptor(
      config: const RetryConfig(
        maxAttempts: 3,
        retryStatusCodes: [408, 429, 500, 502, 503, 504],
        baseDelayMs: 1000,
        multiplier: 2.0,
      ),
      dio: client.dio,
    );

    // 4. Cache Interceptor - Response caching
    final cacheInterceptor = CacheInterceptor(
      config: CacheConfig(
        strategy: CacheStrategy.networkFirst,
        defaultTtl: const Duration(minutes: 5),
        enableDeduplication: true,
      ),
    );
    cacheInterceptor.setDio(client.dio);

    // 5. Logger Interceptor - Request/response logging
    final loggerInterceptor = LoggerInterceptor(
      config: const LoggerConfig(
        level: LogLevel.info,
        logRequestHeaders: true,
        logRequestBody: false,
        logResponseBody: false,
        redactedHeaders: ['Authorization', 'Cookie'],
      ),
    );

    // 6. Sentry Interceptor - Error tracking
    final sentryInterceptor = SentryInterceptor(
      config: SentryConfig(
        captureStatusCodes: {500, 501, 502, 503, 504},
        captureResponseBody: true,
        redactedHeaders: ['Authorization', 'Cookie', 'Set-Cookie'],
        captureException: (exception, {stackTrace, extra, tags}) async {
          await Sentry.captureException(
            exception,
            stackTrace: stackTrace,
            withScope: (scope) {
              extra?.forEach((key, value) {
                scope.setContexts(key, value);
              });
              tags?.forEach((key, value) {
                scope.setTag(key, value);
              });
            },
          );
        },
        addBreadcrumb: (data) {
          Sentry.addBreadcrumb(
            Breadcrumb(
              message: data['message'] as String?,
              category: data['category'] as String?,
              data: data['data'] as Map<String, dynamic>?,
              level: SentryLevel.info,
            ),
          );
        },
      ),
    );

    // 7. Metrics Interceptor - Performance tracking
    final metricsInterceptor = MetricsInterceptor(
      config: MetricsConfig(
        onMetrics: (metrics) {
          // ignore: avoid_print
          print(
            '📊 ${metrics.method} ${metrics.path} '
            '[${metrics.statusCode}] ${metrics.durationMs}ms',
          );
        },
        onBreadcrumb: (breadcrumb) {
          // ignore: avoid_print
          print('🍞 ${breadcrumb.message}');
        },
      ),
    );

    // Add interceptors in order
    client.dio.interceptors.addAll([
      authInterceptor,
      retryInterceptor,
      cacheInterceptor,
      loggerInterceptor,
      sentryInterceptor,
      metricsInterceptor,
    ]);

    return (client: client, cacheInterceptor: cacheInterceptor);
  }
}
