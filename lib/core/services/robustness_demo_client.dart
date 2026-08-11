import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:apix/apix.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// Custom business exception emitted by the response validator on
/// `200 OK + {"success": false}` responses. Extends [ApiException] so the
/// existing `wrapExceptions` / `Result` pipeline catches it transparently.
class BusinessException extends ApiException {
  const BusinessException({
    required super.message,
    required String super.code,
    super.statusCode,
  });

  // `code` used to be declared here. As of apix 4.0.0 it lives on
  // ApiException itself, so redeclaring it would shadow the inherited field —
  // and would not even compile if the types differed.
  @override
  String toString() => 'BusinessException($code): $message';
}

/// In-memory ApiClient that demonstrates the four robustness features added
/// in apix v2.1.0:
///
/// 1. `ParsingException`           — `/malformed-json` returns valid JSON
///    whose shape doesn't match the parser, so `fromJson` throws and apix
///    wraps it.
/// 2. `UnexpectedContentTypeException` — `/captive-portal` returns
///    `text/html`. The client is configured with `strictContentType: true`,
///    so `*AndDecode` rejects it.
/// 3. `BusinessException` via `responseValidator` — `/business-error`
///    returns `200` + `{"success": false}`. The validator translates that
///    into a typed exception.
/// 4. `Retry-After` honoured — `/throttled` returns `503 + Retry-After: 1`
///    on first call, then `200` on the retry. The total wall-clock time
///    proves the wait was honoured.
class RobustnessDemoClient {
  RobustnessDemoClient() {
    final adapter = _RobustnessMockAdapter();
    final config = ApiClientConfig(
      baseUrl: 'https://epic11.demo.local',
      strictContentType: true,
      responseValidator: _validate200Envelope,
    );
    _client = ApiClientFactory.fromConfig(
      config,
      // Tight retry config to keep the demo snappy.
      retryConfig: const RetryConfig(
        maxAttempts: 2,
        retryStatusCodes: [503],
        baseDelayMs: 50,
        maxDelayMs: 5000,
        respectRetryAfter: true,
      ),
      loggerConfig: LoggerConfig.minimal(),
      httpClientAdapter: adapter,
    );
    _adapter = adapter;

    // Second client wired to a deliberately broken TokenProvider — every
    // request goes through AuthInterceptor.onRequest, which calls
    // getAccessToken() and wraps the failure in TokenProviderException.
    _faultyClient = ApiClientFactory.create(
      baseUrl: 'https://epic11.demo.local',
      authConfig: AuthConfig(tokenProvider: const _FaultyTokenProvider()),
      httpClientAdapter: adapter,
      loggerConfig: LoggerConfig.minimal(),
    );
  }

  late final ApiClient _client;
  late final ApiClient _faultyClient;
  late final _RobustnessMockAdapter _adapter;

  ApiClient get client => _client;

  // ---------------------------------------------------------------------
  // Demos
  // ---------------------------------------------------------------------

  /// Triggers `ParsingException`: the response is valid JSON, but the
  /// parser asserts a key/type that doesn't match.
  Future<Map<String, dynamic>> triggerParsingFailure() {
    return _client.getAndDecode<Map<String, dynamic>>('/malformed-json', (
      json,
    ) {
      // Required key is missing → fromJson throws → apix wraps it.
      return {'id': json['id']! as int, 'name': json['name']! as String};
    });
  }

  /// Triggers `UnexpectedContentTypeException`: server replies `text/html`
  /// while we requested a typed-decode (strictContentType is on).
  Future<Map<String, dynamic>> triggerCaptivePortal() {
    return _client.getAndDecode<Map<String, dynamic>>(
      '/captive-portal',
      (json) => json,
    );
  }

  /// Triggers `BusinessException` via `responseValidator`:
  /// the server returns `200 + {"success": false}` and the validator
  /// converts it into a typed exception that bubbles up to the caller.
  Future<Map<String, dynamic>> triggerBusinessError() {
    return _client.getAndDecode<Map<String, dynamic>>(
      '/business-error',
      (json) => json,
    );
  }

  /// Hits an endpoint that returns `503 + Retry-After: 1` once, then `200`.
  /// Returns the elapsed milliseconds so the UI can prove the header was
  /// honoured (~1000ms wait, vs. the 50ms `baseDelayMs` of exponential
  /// backoff).
  Future<int> triggerRetryAfter() async {
    _adapter.resetThrottle();
    final stopwatch = Stopwatch()..start();
    await _client.get<dynamic>('/throttled');
    stopwatch.stop();
    return stopwatch.elapsedMilliseconds;
  }

  /// Hits any endpoint with a [TokenProvider] that throws on read.
  /// Surfaces as [TokenProviderException] (operation: read), itself an
  /// [ApiException] subclass.
  Future<void> triggerTokenProviderFailure() async {
    await _faultyClient.get<dynamic>('/business-error');
  }
}

/// A [TokenProvider] whose `getAccessToken` always throws — simulates a
/// corrupted keychain or a misbehaving custom token store.
class _FaultyTokenProvider implements TokenProvider {
  const _FaultyTokenProvider();

  @override
  Future<String?> getAccessToken() async {
    throw StateError('Keychain unavailable');
  }

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {}

  @override
  Future<void> clearTokens() async {}
}

/// Translates `200 + {"success": false}` envelopes into typed
/// [BusinessException]. Returns `null` for happy responses so they pass.
ApiException? _validate200Envelope(Response<dynamic> response) {
  final data = response.data;
  if (data is Map<String, dynamic> && data['success'] == false) {
    return BusinessException(
      message: (data['error'] ?? 'Unspecified business error').toString(),
      code: (data['code'] ?? 'UNKNOWN').toString(),
      statusCode: response.statusCode,
    );
  }
  return null;
}

/// In-memory mock adapter for the four Epic 11 demo routes.
class _RobustnessMockAdapter implements HttpClientAdapter {
  final HttpClientAdapter _fallback = IOHttpClientAdapter();

  /// Number of times `/throttled` was hit since the last reset. Used to
  /// reply `503` on the first call and `200` on the retry.
  int _throttleHits = 0;

  void resetThrottle() => _throttleHits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final path = options.path;

    if (options.method == 'GET' && path == '/malformed-json') {
      // Valid JSON, wrong shape — `fromJson` will throw.
      return _json({'unexpected': 'shape', 'value': 42});
    }

    if (options.method == 'GET' && path == '/captive-portal') {
      // Captive portal style: 200 + HTML.
      return _html('<html><body>Sign in to use the WiFi</body></html>');
    }

    if (options.method == 'GET' && path == '/business-error') {
      return _json({
        'success': false,
        'code': 'OUT_OF_STOCK',
        'error': 'Article indisponible pour cette commande',
      });
    }

    if (options.method == 'GET' && path == '/throttled') {
      _throttleHits++;
      if (_throttleHits == 1) {
        return _json(
          {'error': 'rate limited'},
          status: 503,
          extraHeaders: {
            'retry-after': ['1'],
          },
        );
      }
      return _json({'success': true, 'attempt': _throttleHits});
    }

    return _json({'error': 'no route for $path'}, status: 404);
  }

  ResponseBody _json(
    Map<String, dynamic> body, {
    int status = 200,
    Map<String, List<String>> extraHeaders = const {},
  }) {
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
        ...extraHeaders,
      },
    );
  }

  ResponseBody _html(String body, {int status = 200}) {
    final bytes = utf8.encode(body);
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) => _fallback.close(force: force);
}
