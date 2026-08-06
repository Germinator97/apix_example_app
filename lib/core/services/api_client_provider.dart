import 'package:apix/apix.dart';
import 'package:flutter/foundation.dart';

/// Centralized API client configuration.
///
/// Wires up every apix module so the app can demonstrate them end-to-end:
/// auth refresh, retry, cache (with shared invalidation API), logging,
/// error tracking with Sentry breadcrumbs, and request metrics.
class ApiClientProvider {
  ApiClientProvider({required this.baseUrl, this.environment = 'development'});

  final String baseUrl;
  final String environment;

  /// Token provider for secure storage.
  late final SecureTokenProvider tokenProvider = SecureTokenProvider();

  /// Cache configuration shared between the interceptor in the Dio chain and
  /// the public [cacheInterceptor] used by the app for invalidation calls.
  late final CacheConfig _cacheConfig = CacheConfig(
    storage: InMemoryCacheStorage(maxEntries: 100),
    strategy: CacheStrategy.networkFirst,
    defaultTtl: const Duration(minutes: 5),
  );

  /// Single [CacheInterceptor] instance — exposed for invalidation and
  /// also installed in the Dio chain so both share the same storage and
  /// the same `setDio` link (required for relative-URL invalidation).
  late final CacheInterceptor cacheInterceptor = CacheInterceptor(
    config: _cacheConfig,
  );

  /// Latest request metrics, refreshed by [MetricsInterceptor] on every call.
  RequestMetrics? lastMetrics;

  /// Auth configuration with simplified refresh + auth-failure callback.
  late final AuthConfig _authConfig = AuthConfig(
    tokenProvider: tokenProvider,
    refreshEndpoint: '/auth/refresh',
    onTokenRefreshed: (response) async {
      final raw = response.data;
      final data = raw is Map<String, dynamic>
          ? raw
          : const <String, dynamic>{};

      final accessToken = (data['access_token'] ?? '').toString();
      final refreshToken =
          (data['refresh_token'] ?? await tokenProvider.getRefreshToken() ?? '')
              .toString();

      if (accessToken.isNotEmpty) {
        await tokenProvider.saveTokens(accessToken, refreshToken);
      }
    },
    onAuthFailure: (provider, error) async {
      await provider.clearTokens();
      await SentrySetup.captureException(
        error ?? const AuthException('Refresh token unavailable'),
        tags: {'auth.event': 'refresh_failure'},
      );
    },
  );

  late final ApiClient client = _build();

  ApiClient _build() {
    final c = ApiClientFactory.create(
      baseUrl: baseUrl,
      authConfig: _authConfig,
      retryConfig: const RetryConfig(
        maxAttempts: 3,
        retryStatusCodes: [500, 502, 503, 504],
        maxDelayMs: 10000,
        // v2.1: honour `Retry-After` header on 429/503 — capped at maxDelayMs.
        // True is the apix default; pinned here for explicit documentation.
        respectRetryAfter: true,
        // v2.3: `retryableMethods` is left at its default — the idempotent
        // methods of RFC 7231 §4.2.2 ({GET, HEAD, OPTIONS, TRACE, PUT,
        // DELETE}). Concretely, the three writes this client performs
        // (`createPost`, `patchPost`, `uploadFile`) are NO LONGER replayed on
        // a 5xx: a gateway 502/504 arriving after the server committed would
        // otherwise duplicate the post/upload. To replay one anyway, opt in
        // per request with `forceRetry()` and make it safe with an
        // `Idempotency-Key` — see `RetryPolicyDemoClient`, which measures
        // both behaviours.
      ),
      loggerConfig: LoggerConfig(
        level: kDebugMode ? LogLevel.info : LogLevel.error,
        redactedHeaders: const ['Authorization', 'Cookie'],
      ),
      errorTrackingConfig: ErrorTrackingConfig(
        environment: environment,
        captureStatusCodes: const {500, 501, 502, 503, 504},
        onError: SentrySetup.captureException,
        onBreadcrumb: SentrySetup.addBreadcrumbFromMap,
      ),
      metricsConfig: MetricsConfig(
        onMetrics: (metrics) {
          lastMetrics = metrics;
          if (kDebugMode) {
            debugPrint(
              '[metrics] ${metrics.method} ${metrics.path} '
              '${metrics.statusCode ?? "?"} ${metrics.durationMs}ms',
            );
          }
        },
      ),
      // v2.1: detect captive portals — typed `*AndDecode` calls verify the
      // response Content-Type starts with `application/json`. JSONPlaceholder
      // returns `application/json; charset=utf-8`, which passes this check.
      strictContentType: true,
      // Install the shared cache interceptor as a custom interceptor so the
      // public `cacheInterceptor` references the exact instance Dio uses.
      interceptors: [cacheInterceptor],
    );

    // Required for `invalidateUrl(<relative>)` to resolve against baseUrl.
    cacheInterceptor.setDio(c.dio);
    return c;
  }
}
