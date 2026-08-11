import 'dart:convert';
import 'dart:io';

import 'package:apix/apix.dart';
import 'package:apix/testing.dart';

/// Which 5.0.0 fix a probe exercises.
///
/// All six were found by auditing the package rather than reported from the
/// field, and every one of them was **silent**: no exception, no log, no red
/// test. That is what these probes are for — each shows the evidence that used
/// to be missing.
enum V5Probe {
  /// Two accounts on one device must not share a cache entry.
  cacheIsScopedToCaller,

  /// `?page=1` and `?page=2` written into the path are different requests.
  inlineQueryDoesNotCollide,

  /// A nested map keeps its siblings and its nesting on the wire.
  nestedMultipartKeepsEverything,

  /// An upload survives a token refresh, because its body is rebuilt.
  uploadSurvivesTokenRefresh,

  /// A business failure dressed as `200 OK` is measured as a failure.
  businessFailureIsNotASuccess,

  /// An empty collection sent as a bare `[]` is an empty list, not a crash.
  bareArrayIsAnEmptyList,
}

/// What a probe observed. Records what actually happened rather than a
/// pass/fail, so the screen can show the evidence.
class V5ProbeResult {
  const V5ProbeResult({
    required this.probe,
    required this.headline,
    required this.detail,
  });

  final V5Probe probe;

  /// One-line outcome, shown in the status bar.
  final String headline;

  /// The supporting evidence — a count, a body, a flag.
  final String detail;
}

/// In-memory [ApiClient] demonstrating what apix 5.0.0 fixed.
///
/// The 4.x probes answered an integration report: things apix knew and the
/// consumer could not reach. These answer an audit instead, and they share a
/// different shape — every defect sat at a *junction* between two interceptors
/// that were each correct alone, and produced a wrong answer rather than an
/// error. Nothing crashed; the cache simply returned the previous account's
/// body, the upload simply arrived empty.
class V5DemoClient {
  V5DemoClient();

  /// Runs [probe] and reports what was observed.
  Future<V5ProbeResult> run(V5Probe probe) async {
    return switch (probe) {
      V5Probe.cacheIsScopedToCaller => _cacheScoping(),
      V5Probe.inlineQueryDoesNotCollide => _inlineQuery(),
      V5Probe.nestedMultipartKeepsEverything => _nestedMultipart(),
      V5Probe.uploadSurvivesTokenRefresh => _uploadReplay(),
      V5Probe.businessFailureIsNotASuccess => _businessFailure(),
      V5Probe.bareArrayIsAnEmptyList => _bareArray(),
    };
  }

  /// Log out, log back in as someone else, ask for `/me` again.
  Future<V5ProbeResult> _cacheScoping() async {
    // Echoes back whichever token was presented, so the body itself says which
    // account the answer belongs to.
    final adapter = _EchoAdapter(
      (options) => {'me': options.headers['Authorization']},
    );
    final tokens = _MutableTokenProvider('token-A');
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      authConfig: AuthConfig(tokenProvider: tokens),
      cacheConfig: CacheConfig(
        strategy: CacheStrategy.cacheFirst,
        defaultTtl: const Duration(minutes: 10),
      ),
      httpClientAdapter: adapter,
    );

    final asA = await client.get<dynamic>('/me');
    tokens.accessToken = 'token-B';
    final asB = await client.get<dynamic>('/me');

    final bodyA = (asA.data as Map)['me'];
    final bodyB = (asB.data as Map)['me'];
    final leaked = bodyA == bodyB;

    return V5ProbeResult(
      probe: V5Probe.cacheIsScopedToCaller,
      headline: leaked
          ? 'LEAK — B was served "$bodyA"'
          : 'A got "$bodyA", B got "$bodyB" (${adapter.hits} calls)',
      detail:
          'The cache key described what was asked and never who asked, so two '
          'accounts on one device shared every entry — and FileCacheStorage '
          'persists, so the leak outlived the session. Scoped now by '
          'CacheConfig.varyHeaders, on a digest so no bearer token is written '
          'beside the entry.',
    );
  }

  /// The same endpoint, two pages, written the way most callers write them.
  Future<V5ProbeResult> _inlineQuery() async {
    final adapter = _EchoAdapter((options) => {'uri': options.uri.toString()});
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      cacheConfig: CacheConfig(
        strategy: CacheStrategy.cacheFirst,
        defaultTtl: const Duration(minutes: 10),
      ),
      httpClientAdapter: adapter,
    );

    final first = await client.get<dynamic>('/users?page=1');
    final second = await client.get<dynamic>('/users?page=2');

    final firstUri = (first.data as Map)['uri'] as String;
    final secondUri = (second.data as Map)['uri'] as String;
    final collided = firstUri == secondUri;

    return V5ProbeResult(
      probe: V5Probe.inlineQueryDoesNotCollide,
      headline: collided
          ? 'COLLISION — page=2 was served page=1'
          : '2 pages → ${adapter.hits} calls, distinct bodies',
      detail:
          'The key was rebuilt from queryParameters, which is empty when the '
          'caller writes the query into the path — so both pages shared one '
          'entry. The same two pages passed as queryParameters did not '
          'collide, so whether it fired depended on how you spelled the call.',
    );
  }

  /// A form with a file nested inside an object, next to a plain field.
  Future<V5ProbeResult> _nestedMultipart() async {
    final file = await _tempFile('avatar.png', 'not-really-an-image');
    final adapter = _EchoAdapter((options) => {'ok': true});
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      httpClientAdapter: adapter,
    );

    await client.post<dynamic>(
      '/profile',
      data: {
        'user': {'avatar': file, 'name': 'John'},
      },
    );

    final sent = adapter.lastRequest!.data as FormData;
    final fields = sent.fields.map((e) => '${e.key}=${e.value}').join(', ');
    final files = sent.files.map((e) => e.key).join(', ');
    final complete = sent.files.length == 1 && sent.fields.length == 1;

    return V5ProbeResult(
      probe: V5Probe.nestedMultipartKeepsEverything,
      headline: complete
          ? 'Sent files[$files] fields[$fields]'
          : 'LOSS — files[$files] fields[$fields]',
      detail:
          'File detection was recursive, the conversion one level deep, so '
          'everything below that level was dropped without a word while the '
          'server answered 200. A file two levels down sent an EMPTY body.',
    );
  }

  /// An upload that meets an expired token — the commonest thing in the world.
  Future<V5ProbeResult> _uploadReplay() async {
    final file = await _tempFile('report.pdf', 'pdf-bytes');
    var calls = 0;
    final adapter = _EchoAdapter((options) {
      if (options.path.contains('refresh')) {
        return {'access_token': 'fresh-token'};
      }
      calls++;
      // First attempt: the token is stale. The replay must carry a body of its
      // own, or it never gets this far.
      if (calls == 1) throw _Unauthorized();
      return {'uploaded': true};
    });

    final tokens = _MutableTokenProvider('stale-token');
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      authConfig: AuthConfig(
        tokenProvider: tokens,
        refreshEndpoint: '/auth/refresh',
        onTokenRefreshed: (response) async {
          await tokens.saveTokens('fresh-token', 'fresh-refresh');
        },
      ),
      httpClientAdapter: adapter,
    );

    try {
      final response = await client.post<dynamic>(
        '/upload',
        data: {'file': file, 'caption': 'holiday'},
      );
      final replayed = adapter.lastRequest!.data as FormData;
      return V5ProbeResult(
        probe: V5Probe.uploadSurvivesTokenRefresh,
        headline:
            'HTTP ${response.statusCode} after refresh — replay carried '
            '${replayed.files.length} file, ${replayed.fields.length} field',
        detail:
            'A FormData is single-use, and both the refresh and the retry '
            'replay the original RequestOptions — so an upload with an expired '
            'token failed outright. The refresh queue, the headline feature, '
            'was inoperative for uploads. apix now rebuilds the body per '
            'attempt.',
      );
    } on ApiException catch (e) {
      return V5ProbeResult(
        probe: V5Probe.uploadSurvivesTokenRefresh,
        headline: 'REGRESSION — the replayed upload failed',
        detail: '${e.runtimeType}: ${e.message}',
      );
    }
  }

  /// HTTP 200, `{"success": false}` — a legacy API's way of saying no.
  Future<V5ProbeResult> _businessFailure() async {
    final measured = <RequestMetrics>[];
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      metricsConfig: MetricsConfig(onMetrics: measured.add),
      cacheConfig: CacheConfig(
        strategy: CacheStrategy.cacheFirst,
        defaultTtl: const Duration(minutes: 10),
      ),
      responseValidator: (response) {
        final data = response.data;
        if (data is Map && data['success'] == false) {
          return ApiException(message: data['message'] as String);
        }
        return null;
      },
      httpClientAdapter: _EchoAdapter(
        (options) => {'success': false, 'message': 'Commande refusée.'},
      ),
    );

    var refused = false;
    try {
      await client.get<dynamic>('/orders');
    } on ApiException {
      refused = true;
    }

    final metric = measured.isEmpty ? null : measured.first;
    final counted = metric?.success;

    return V5ProbeResult(
      probe: V5Probe.businessFailureIsNotASuccess,
      headline: counted == false
          ? 'Refused, and measured success=false'
          : 'REGRESSION — measured success=$counted',
      detail:
          'The validator ran after the cache and after every observer, so the '
          'refused body was cached — and a cache hit skips response '
          'interceptors, so it came back unvalidated, as a success. Metrics '
          'had already recorded success=true: the dashboards counted as fine '
          'the exact failures this feature exists to surface. '
          '(refused=$refused)',
    );
  }

  /// The endpoint that returns `[]` when the user has nothing yet.
  Future<V5ProbeResult> _bareArray() async {
    final client = ApiClientFactory.create(
      baseUrl: 'https://demo.apix',
      httpClientAdapter: _EchoAdapter((options) => <dynamic>[]),
    );

    try {
      final rows = await client
          .getListAndDecodeDataOrEmpty<Map<String, dynamic>>(
            '/reports',
            (json) => json,
          );
      return V5ProbeResult(
        probe: V5Probe.bareArrayIsAnEmptyList,
        headline: 'Got ${rows.length} rows — no crash',
        detail:
            'Backends serialise an empty collection as [] rather than '
            '{"data": []}, and the unwrapper rejected it — so the methods whose '
            'whole purpose is tolerating "no data" broke on the commonest '
            'spelling of it, under HTTP 200, on the user who had nothing yet.',
      );
    } on ApiException catch (e) {
      return V5ProbeResult(
        probe: V5Probe.bareArrayIsAnEmptyList,
        headline: 'REGRESSION — a bare [] still throws',
        detail: '${e.runtimeType}: ${e.message}',
      );
    }
  }

  /// Writes [contents] to a real file, because the multipart probes are about
  /// what happens to a `File` and a stub would prove nothing.
  Future<File> _tempFile(String name, String contents) async {
    final dir = await Directory.systemTemp.createTemp('apix_v5_demo');
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(contents);
    return file;
  }
}

/// Answers from a callback, recording hits and the last request it saw.
class _EchoAdapter implements HttpClientAdapter {
  _EchoAdapter(this.respond);

  /// Builds the body from the request. Throwing [_Unauthorized] answers 401.
  final Object? Function(RequestOptions options) respond;

  int hits = 0;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    hits++;
    lastRequest = options;
    try {
      final body = respond(options);
      return _json(body, 200);
    } on _Unauthorized {
      return _json({'message': 'Token expiré.'}, 401);
    }
  }

  ResponseBody _json(Object? body, int statusCode) => ResponseBody.fromBytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {
      Headers.contentTypeHeader: const ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Signals "answer 401" from inside an [_EchoAdapter] callback.
class _Unauthorized implements Exception {}

/// A token provider whose token can change mid-run, which is what a logout
/// followed by a login looks like from the client's side.
class _MutableTokenProvider implements TokenProvider {
  _MutableTokenProvider(this.accessToken);

  String? accessToken;
  String? refreshToken = 'refresh-token';

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}
