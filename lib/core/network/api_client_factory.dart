import 'package:apix/apix.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../data/datasources/local_data_source.dart';

/// Factory for creating a fully configured ApiClient with all interceptors.
class AppApiClientFactory {
  final LocalDataSource _localDataSource;

  AppApiClientFactory(this._localDataSource);

  /// Creates the ApiClient with all apix interceptors configured.
  ({ApiClient client, CacheInterceptor cacheInterceptor}) create() {
    final tokenProvider = _localDataSource.tokenProvider;

    final cacheConfig = CacheConfig(
      strategy: CacheStrategy.networkFirst,
      defaultTtl: const Duration(minutes: 5),
      enableDeduplication: true,
    );

    final client = ApiClientFactory.create(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'X-App-Version': '1.0.0', 'Accept': 'application/json'},

      authConfig: AuthConfig(
        tokenProvider: tokenProvider,
        headerName: 'Authorization',
        headerPrefix: 'Bearer',
        refreshStatusCodes: [401],
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

      retryConfig: const RetryConfig(
        maxAttempts: 3,
        retryStatusCodes: [408, 429, 500, 502, 503, 504],
        baseDelayMs: 1000,
        multiplier: 2.0,
      ),

      cacheConfig: cacheConfig,

      loggerConfig: const LoggerConfig(
        level: LogLevel.info,
        logRequestHeaders: true,
        logRequestBody: false,
        logResponseBody: false,
        redactedHeaders: ['Authorization', 'Cookie'],
      ),

      errorTrackingConfig: ErrorTrackingConfig(
        captureStatusCodes: {500, 501, 502, 503, 504},
        captureResponseBody: true,
        redactedHeaders: ['Authorization', 'Cookie', 'Set-Cookie'],
        onError: (exception, {stackTrace, extra, tags}) async {
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
        onBreadcrumb: (data) {
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

      metricsConfig: MetricsConfig(
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

    final cacheInterceptor = CacheInterceptor(config: cacheConfig);

    return (client: client, cacheInterceptor: cacheInterceptor);
  }
}
