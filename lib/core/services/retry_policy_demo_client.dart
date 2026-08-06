import 'dart:convert';
import 'dart:typed_data';

import 'package:apix/apix.dart';
import 'package:dio/dio.dart'
    show HttpClientAdapter, Headers, RequestOptions, ResponseBody;
import 'package:dio/io.dart';

/// Which retry behaviour a probe exercises.
enum RetryProbe {
  /// `GET` — an idempotent method, retried by default.
  idempotentGet,

  /// `POST` — non-idempotent, **not** retried since apix 2.3.0.
  nonIdempotentPost,

  /// `POST` + `forceRetry()` — opt-in replay for a request that is provably
  /// safe to repeat (here, protected by an `Idempotency-Key`).
  forcedPost,
}

/// Outcome of a single probe: how many times the server was actually hit.
class RetryProbeResult {
  const RetryProbeResult({
    required this.probe,
    required this.attempts,
    required this.expectedAttempts,
  });

  final RetryProbe probe;

  /// Times the (mocked) server received the request, retries included.
  final int attempts;

  /// What the configured [RetryConfig] implies for this probe.
  final int expectedAttempts;

  bool get matchesPolicy => attempts == expectedAttempts;

  /// True when the request was replayed at least once.
  bool get wasRetried => attempts > 1;
}

/// In-memory [ApiClient] demonstrating the **method-aware retry** introduced
/// in apix 2.3.0.
///
/// Every route replies `503`, which is in [RetryConfig.retryStatusCodes], so
/// the *only* thing that decides whether the request is replayed is the HTTP
/// method — and, for a non-idempotent one, an explicit `forceRetry()` opt-in.
///
/// Why this demo exists: before 2.3.0 a `POST` that returned `5xx` **after**
/// the server had already committed (a gateway `502`/`504` following an
/// order) was replayed, duplicating the side effect. The default
/// [RetryConfig.retryableMethods] now covers only the idempotent methods of
/// RFC 7231 §4.2.2, so `POST`/`PATCH` are left alone unless you say otherwise.
class RetryPolicyDemoClient {
  RetryPolicyDemoClient() {
    final adapter = _AttemptCountingAdapter();
    _adapter = adapter;
    _client = ApiClientFactory.create(
      baseUrl: 'https://retry-policy.demo.local',
      // Short delays keep the demo snappy; `retryableMethods` is deliberately
      // left at its default so the demo measures the shipped policy, not a
      // local override.
      retryConfig: retryConfig,
      loggerConfig: LoggerConfig.minimal(),
      httpClientAdapter: adapter,
    );
  }

  /// Exposed so the UI and the tests derive their expectations from the very
  /// config the client runs on, instead of restating numbers that would drift.
  static const RetryConfig retryConfig = RetryConfig(
    maxAttempts: 2,
    retryStatusCodes: [503],
    baseDelayMs: 20,
    maxDelayMs: 200,
  );

  late final ApiClient _client;
  late final _AttemptCountingAdapter _adapter;

  /// Attempts expected for [probe] under [retryConfig]: one initial call, plus
  /// [RetryConfig.maxAttempts] replays when the request is eligible.
  static int expectedAttemptsFor(RetryProbe probe) {
    final eligible = switch (probe) {
      RetryProbe.idempotentGet => retryConfig.shouldRetryMethod('GET'),
      RetryProbe.nonIdempotentPost => retryConfig.shouldRetryMethod('POST'),
      // forceRetry() overrides the method guard, never the attempt budget.
      RetryProbe.forcedPost => true,
    };
    return eligible ? retryConfig.maxAttempts + 1 : 1;
  }

  /// Runs [probe] against the always-`503` route and reports how many times
  /// the server was hit.
  ///
  /// The call is expected to fail with the route's `503`; that failure is the
  /// point of the probe, so it is swallowed and only the attempt count is
  /// returned. Any *other* outcome is rethrown — a probe that silently
  /// succeeded, or failed for another reason, would report a meaningless
  /// count.
  ///
  Future<RetryProbeResult> run(RetryProbe probe) async {
    _adapter.reset();
    try {
      switch (probe) {
        case RetryProbe.idempotentGet:
          await _client.get<dynamic>('/flaky');
        case RetryProbe.nonIdempotentPost:
          await _client.post<dynamic>('/flaky', data: {'quantity': 2});
        case RetryProbe.forcedPost:
          await _client.post<dynamic>(
            '/flaky',
            data: {'quantity': 2},
            options: Options(
              // A replay is only safe because the server can de-duplicate on
              // this key. Without it, forceRetry() would reintroduce the very
              // duplicate order the method guard prevents.
              headers: {'Idempotency-Key': 'demo-fixed-key-0001'},
              extra: {forceRetryKey: true},
            ),
          );
      }
    } on ServerException catch (e) {
      // Expected: the route always answers 503. The attempt count is the
      // signal, not the failure itself.
      if (e.statusCode != 503) rethrow;
    }
    return RetryProbeResult(
      probe: probe,
      attempts: _adapter.attempts,
      expectedAttempts: expectedAttemptsFor(probe),
    );
  }
}

/// Adapter that always answers `503` and counts how many times it was called.
class _AttemptCountingAdapter implements HttpClientAdapter {
  final HttpClientAdapter _fallback = IOHttpClientAdapter();

  int attempts = 0;

  void reset() => attempts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    attempts++;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'error': 'upstream unavailable'})),
      503,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) => _fallback.close(force: force);
}
