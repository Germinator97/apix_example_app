import 'dart:convert';

import 'package:apix/apix.dart';
// a review point in action: adapter stubbing now comes from apix itself. This file has no
// `package:dio` import, which is exactly what 4.0.0 set out to make possible.
import 'package:apix/testing.dart';

/// Which 4.0.0 behaviour a probe exercises.
enum V4Probe {
  /// A `409` carrying `{"code": "OUT_OF_STOCK"}` — the status is the
  /// unstable part, the code is the one worth branching on.
  applicationErrorCode,

  /// A `429` with `Retry-After: 45`, surfaced as a typed exception.
  rateLimited,

  /// Three identical concurrent `GET`s, collapsed into one call **without**
  /// any cache being installed.
  deduplicationWithoutCache,

  /// A `networkOnly` request: served from the network, and stored nowhere.
  networkOnlyStoresNothing,

  /// (4.1.0) A log sink that throws on every entry — the request must still
  /// return its 200.
  brokenObserverIsHarmless,
}

/// What a probe observed. Deliberately records what actually happened rather
/// than a pass/fail, so the screen can show the evidence.
class V4ProbeResult {
  const V4ProbeResult({
    required this.probe,
    required this.headline,
    required this.detail,
  });

  final V4Probe probe;

  /// One-line outcome, shown in the list.
  final String headline;

  /// The supporting evidence — a count, a code, a duration.
  final String detail;
}

/// In-memory [ApiClient] demonstrating what apix 4.0.0 added, all of it driven
/// by the integration report a consumer filed against 3.0.0.
///
/// Every gap it closes had the same shape: apix knew something the consumer
/// could not reach. An error code it read past, a `Retry-After` it parsed and
/// dropped, a response it stored on a strategy that never reads.
class V4DemoClient {
  V4DemoClient();

  /// Runs [probe] and reports what was observed.
  Future<V4ProbeResult> run(V4Probe probe) async {
    return switch (probe) {
      V4Probe.applicationErrorCode => _applicationErrorCode(),
      V4Probe.rateLimited => _rateLimited(),
      V4Probe.deduplicationWithoutCache => _deduplication(),
      V4Probe.networkOnlyStoresNothing => _networkOnly(),
      V4Probe.brokenObserverIsHarmless => _brokenObserver(),
    };
  }

  /// A business failure whose HTTP status may drift between server revisions,
  /// but whose `code` does not.
  Future<V4ProbeResult> _applicationErrorCode() async {
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      httpClientAdapter: _ScriptedAdapter(
        statusCode: 409,
        body: {
          'code': 'OUT_OF_STOCK',
          'message': 'Article indisponible pour cette commande.',
        },
      ),
    );

    try {
      await client.post<void>('/orders', data: {'quantity': 3});
      return const V4ProbeResult(
        probe: V4Probe.applicationErrorCode,
        headline: 'Unexpected success',
        detail: 'the stub always answers 409',
      );
    } on ApiException catch (e) {
      // This switch is the point: it keeps working if the backend moves this
      // case from 409 to 422 tomorrow. A `statusCode` branch would not.
      final reaction = switch (e.code) {
        'OUT_OF_STOCK' => 'Proposer une alternative',
        'OPERATION_NOT_RETRYABLE' => 'Refus définitif',
        _ => 'Message générique',
      };
      return V4ProbeResult(
        probe: V4Probe.applicationErrorCode,
        headline: 'code=${e.code} → $reaction',
        detail:
            'HTTP ${e.statusCode} — the status could drift, the code will '
            'not. Before 4.0.0 this meant digging through responseBody by hand.',
      );
    }
  }

  /// A rate limit the user can actually be told the length of.
  Future<V4ProbeResult> _rateLimited() async {
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      httpClientAdapter: _ScriptedAdapter(
        statusCode: 429,
        body: {'message': 'Too many requests'},
        headers: {
          'retry-after': ['45'],
        },
      ),
    );

    try {
      await client.get<void>('/reports');
      return const V4ProbeResult(
        probe: V4Probe.rateLimited,
        headline: 'Unexpected success',
        detail: 'the stub always answers 429',
      );
    } on TooManyRequestsException catch (e) {
      final wait = e.retryAfter;
      return V4ProbeResult(
        probe: V4Probe.rateLimited,
        headline: wait == null
            ? 'Réessayez plus tard (délai inconnu)'
            : 'Réessayez dans ${wait.inSeconds} s',
        // No `e is ClientException` check here: the analyzer rejects it as
        // always true, which is itself the proof — the subtype relationship
        // holds statically, so existing `on ClientException` clauses cannot
        // stop matching a 429.
        detail:
            'HTTP ${e.statusCode}, caught as TooManyRequestsException — a '
            'subtype of ClientException, so existing catch clauses still '
            'match. Before 4.0.0 the Retry-After value was parsed and dropped.',
      );
    }
  }

  /// Deduplication with no `cacheConfig` anywhere in sight.
  Future<V4ProbeResult> _deduplication() async {
    final adapter = _ScriptedAdapter(statusCode: 200, body: {'value': 'ok'});
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      deduplicationConfig: const DeduplicationConfig(),
      httpClientAdapter: adapter,
    );

    await Future.wait([
      client.get<dynamic>('/profile'),
      client.get<dynamic>('/profile'),
      client.get<dynamic>('/profile'),
    ]);
    final concurrent = adapter.hits;

    // A later request must still reach the network: this is deduplication,
    // not caching.
    await client.get<dynamic>('/profile');

    return V4ProbeResult(
      probe: V4Probe.deduplicationWithoutCache,
      headline:
          '3 concurrent GETs → $concurrent call, '
          '${adapter.hits - concurrent} more when repeated later',
      detail:
          'No cacheConfig at all. Before 4.0.0 this required installing '
          'the cache, then supplying a CacheStorage that dropped its writes.',
    );
  }

  /// `networkOnly` documents "never read cache" — it now also never writes.
  Future<V4ProbeResult> _networkOnly() async {
    final storage = InMemoryCacheStorage();
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      cacheConfig: CacheConfig(
        storage: storage,
        strategy: CacheStrategy.networkOnly,
      ),
      httpClientAdapter: _ScriptedAdapter(
        statusCode: 200,
        body: {'email': 'jane@example.test', 'plan': 'premium'},
      ),
    );

    await client.get<dynamic>('/quota');
    final stored = await storage.keys();

    return V4ProbeResult(
      probe: V4Probe.networkOnlyStoresNothing,
      headline: stored.isEmpty
          ? 'Nothing written to the store'
          : 'LEAK — ${stored.length} entr${stored.length == 1 ? "y" : "ies"} '
                'written',
      detail:
          'Until 4.0.0 only the *reading* half was enforced, so a profile '
          'went through a store nobody ever read from.',
    );
  }

  /// An observation callback that fails must not decide whether the request
  /// succeeded.
  Future<V4ProbeResult> _brokenObserver() async {
    var attempts = 0;
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      loggerConfig: LoggerConfig(
        level: LogLevel.info,
        logHandler: (_) {
          attempts++;
          throw StateError('log sink is down');
        },
      ),
      httpClientAdapter: _ScriptedAdapter(
        statusCode: 200,
        body: {'value': 'ok'},
      ),
    );

    try {
      final response = await client.get<dynamic>('/profile');
      return V4ProbeResult(
        probe: V4Probe.brokenObserverIsHarmless,
        headline:
            'HTTP ${response.statusCode} despite $attempts failed '
            'log write${attempts == 1 ? "" : "s"}',
        detail:
            'Before 4.1.0 this returned an ApiException: a log sink, an '
            'analytics backend or a span starter having a bad minute failed '
            'the business request it was only supposed to observe.',
      );
    } on ApiException catch (e) {
      return V4ProbeResult(
        probe: V4Probe.brokenObserverIsHarmless,
        headline: 'REGRESSION — the log sink broke the request',
        detail: '${e.runtimeType}: ${e.message}',
      );
    }
  }
}

/// Answers a fixed response, counting how many times it was reached.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final Map<String, dynamic> body;
  final Map<String, List<String>> headers;

  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    hits++;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: const ['application/json'],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
