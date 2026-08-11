import 'dart:io';

import 'package:apix/apix.dart';
import 'package:flutter/foundation.dart';

/// Centralized API client configuration.
///
/// Wires up every apix module so the app can demonstrate them end-to-end:
/// auth refresh, retry, cache (with shared invalidation API), logging,
/// error tracking with Sentry breadcrumbs, and request metrics.
class ApiClientProvider {
  ApiClientProvider({
    required this.baseUrl,
    required this.cacheDirectory,
    this.environment = 'development',
  });

  final String baseUrl;
  final String environment;

  /// Where the persistent cache is written.
  ///
  /// Resolved by the app (via `path_provider`) and handed to apix, which
  /// deliberately does not depend on `path_provider` itself.
  final Directory cacheDirectory;

  /// Token provider for secure storage.
  late final SecureTokenProvider tokenProvider = SecureTokenProvider();

  /// Cache configuration shared between the interceptor in the Dio chain and
  /// the public [cacheInterceptor] used by the app for invalidation calls.
  late final CacheConfig _cacheConfig = CacheConfig(
    // apix 3.0.0: survives restarts, unlike InMemoryCacheStorage which starts
    // empty on every cold start — exactly when the wait is most visible. The
    // app can prove it: fetch posts, kill the app, reopen, and the list paints
    // from disk.
    //
    // Bounded on purpose. A process cache disappears when the app closes; a
    // disk cache does not, so leaving it unbounded would keep every response
    // this demo ever made.
    //
    // ⚠️ Clear text on disk. JSONPlaceholder posts are public sample data, so
    // that is acceptable *here* and nowhere near identity or money.
    //
    // v4.0 offers EncryptedCacheStorage for exactly that case — it wraps this
    // storage and seals body and headers with a cipher you supply:
    //
    //   storage: EncryptedCacheStorage(
    //     delegate: FileCacheStorage(dir, maxEntries: 100),
    //     encrypt: myCipher.seal,
    //     decrypt: myCipher.open,
    //   ),
    //
    // Left unwrapped on purpose: wiring a real cipher here would add a crypto
    // dependency this demo does not need, and a toy one in an example app is
    // precisely the thing that gets copied into production. Note that cache
    // *keys* stay readable either way, so keep identifiers out of URLs you
    // cache.
    storage: FileCacheStorage(
      Directory('${cacheDirectory.path}/apix_cache'),
      maxEntries: 100,
    ),
    strategy: CacheStrategy.networkFirst,
    defaultTtl: const Duration(minutes: 5),
  );

  /// The cache interceptor the client is actually using, for the invalidation
  /// buttons.
  ///
  /// Looked up rather than built here. This used to construct its own instance
  /// and pass it through `interceptors:` purely to keep a reference — which put
  /// a *re-entrant* interceptor after the observers, so its inner request was
  /// logged a second time. `cacheConfig` places it before them, and
  /// `ApiClient.cacheInterceptor` hands back the same instance.
  CacheInterceptor get cacheInterceptor => client.cacheInterceptor!;

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
        //
        // v4.0: `jitter` is left at its default (0.2, i.e. ±20 %). It is ON
        // deliberately — a strictly deterministic backoff makes every client
        // that failed in the same outage second retry at the same instants,
        // meeting the recovering server with a synchronised spike. Pass 0.0
        // only where a test needs an exact delay.
      ),
      // v4.0: without this, a retry storm is invisible — only the final
      // failure ever surfaces, never the attempts that led to it.
      onRetry: (attempt) {
        if (kDebugMode) {
          debugPrint(
            '[retry] #${attempt.attempt} in ${attempt.delay.inMilliseconds}ms '
            '(status ${attempt.statusCode})',
          );
        }
      },
      // v4.0: one performance span per request, as a child of the current
      // Sentry transaction. apix already measured durations; this is what
      // makes them aggregatable rather than visible only after an incident.
      tracingConfig: const TracingConfig(),
      loggerConfig: LoggerConfig(
        level: kDebugMode ? LogLevel.info : LogLevel.error,
        redactedHeaders: const ['Authorization', 'Cookie'],
      ),
      // apix 3.0.0: `onError` hands over the TYPED ApiException, so Sentry
      // files a 500 (ServerException) and a 404 (NotFoundException) as
      // distinct issues instead of lumping everything under `DioException`.
      // Transport failures (TimeoutException, ConnectionException) are then
      // filtered as network noise and never reach Sentry — which is why a
      // dropped connection shows in the status bar but not in the dashboard.
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
      // Through cacheConfig, so the factory places it before the observers and
      // calls setDio for us — the latter is what makes
      // `invalidateUrl(<relative>)` resolve against baseUrl.
      cacheConfig: _cacheConfig,
    );
    return c;
  }
}
