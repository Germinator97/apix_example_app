import 'package:apix/apix.dart';

import '../services/error_tracking_demo_client.dart';
import 'demo_probe.dart';
import 'scripted_adapter.dart';

/// What reaches the tracker, what is filtered as noise, and what an observer
/// is never allowed to do.
///
/// The rule underneath all three: observation is a side channel. A request
/// that succeeded must still succeed when the analytics backend is down, and a
/// failure must be reported as itself rather than as a bare `DioException`.
List<DemoProbe> observabilityProbes(ErrorTrackingDemoClient tracking) => [
  DemoProbe(
    id: 'observability.server_error_reported',
    theme: ProbeTheme.observability,
    label: '500 → reported',
    run: () => _tracking(tracking, TrackingProbe.serverError),
  ),
  DemoProbe(
    id: 'observability.connection_lost_filtered',
    theme: ProbeTheme.observability,
    label: 'Connection lost → filtered',
    run: () => _tracking(tracking, TrackingProbe.connectionLost),
  ),
  DemoProbe(
    id: 'observability.broken_sink_is_harmless',
    theme: ProbeTheme.observability,
    label: 'A broken log sink is harmless',
    run: _brokenSinkIsHarmless,
  ),
  DemoProbe(
    id: 'observability.retry_leaves_nothing_in_flight',
    theme: ProbeTheme.observability,
    label: 'A retry storm strands no metric',
    run: _retryLeavesNothingInFlight,
  ),
  DemoProbe(
    id: 'observability.error_body_stays_out_of_logs',
    theme: ProbeTheme.observability,
    label: 'An error body stays out of the logs',
    run: _errorBodyStaysOutOfLogs,
  ),
  DemoProbe(
    id: 'observability.query_values_never_reach_the_tracker',
    theme: ProbeTheme.observability,
    label: 'A token in the query is redacted',
    run: _queryValuesNeverReachTheTracker,
  ),
];

/// Fail twice, succeed once, then look at the in-flight ledger.
Future<ProbeOutcome> _retryLeavesNothingInFlight() async {
  var attempt = 0;
  final emitted = <RequestMetrics>[];
  final adapter = ScriptedAdapter((options) {
    attempt++;
    return attempt < 3
        ? const ScriptedResponse({'message': 'unavailable'}, statusCode: 503)
        : {'ok': true};
  });
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    retryConfig: const RetryConfig(maxAttempts: 2, baseDelayMs: 1, jitter: 0),
    metricsConfig: MetricsConfig(onMetrics: emitted.add),
    httpClientAdapter: adapter,
  );

  await client.get<dynamic>('/orders');
  final metrics = client.dio.interceptors.whereType<MetricsInterceptor>().first;

  return ProbeOutcome(
    headline:
        '${adapter.hits} attempts → ${emitted.length} metric, '
        '${metrics.inFlightCount} left in flight',
    detail:
        'Each attempt created a fresh entry and overwrote the id pointing at '
        'the previous one, so two were stranded until the five-minute orphan '
        'sweep. No exception, no wrong callback value — just a count nobody '
        'reads, healing itself just slowly enough to look like it was never '
        'there. One logical request is one metric, and its duration now covers '
        'the backoff the caller actually waited through.',
  );
}

/// A 500 carrying personal data, with bodies switched off.
Future<ProbeOutcome> _errorBodyStaysOutOfLogs() async {
  final entries = <LogEntry>[];
  final adapter = ScriptedAdapter(
    (options) => const ScriptedResponse({
      'message': 'refused',
      'email': 'someone@example.com',
    }, statusCode: 500),
  );
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    loggerConfig: LoggerConfig(logResponseBody: false, logHandler: entries.add),
    httpClientAdapter: adapter,
  );

  try {
    await client.get<dynamic>('/orders');
  } on ApiException {
    // The failure is the point of the probe.
  }

  final error = entries.firstWhere((e) => e.level == LogLevel.error);

  return ProbeOutcome(
    headline: error.body == null
        ? 'body withheld, status ${error.statusCode} still logged'
        : 'LEAK — ${error.body}',
    detail:
        '5.0 turned body logging off by default because a plain LoggerConfig '
        'printed the password in a POST /login. The success path was changed; '
        'the error path was not, and it is the side where a body is most '
        'likely to describe the user who just failed. LoggerConfig.minimal(), '
        'whose whole purpose is to say nothing, said this.',
  );
}

/// A reset link with a token in the query, failing.
Future<ProbeOutcome> _queryValuesNeverReachTheTracker() async {
  final contexts = <Map<String, dynamic>>[];
  final adapter = ScriptedAdapter(
    (options) => const ScriptedResponse({'message': 'boom'}, statusCode: 500),
  );
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    errorTrackingConfig: ErrorTrackingConfig(
      onError: (exception, {stackTrace, extra, tags}) async {
        if (extra != null) contexts.add(extra);
      },
    ),
    httpClientAdapter: adapter,
  );

  try {
    await client.get<dynamic>(
      '/reset',
      queryParameters: {'token': 'super-secret-value', 'lang': 'fr'},
    );
  } on ApiException {
    // Expected.
  }

  final url = contexts.isEmpty ? '(nothing captured)' : contexts.first['url'];

  return ProbeOutcome(
    headline: '$url',
    detail:
        'This interceptor redacted Authorization, Cookie and Set-Cookie — and '
        'then sent the whole URI, so a token in a query parameter reached a '
        'third-party service in clear, PAST a redaction step that had already '
        'run. A half-applied redaction is worse than none: it reads as '
        'complete, so nobody looks again. Names are kept, because knowing '
        'which parameters a failing request carried is most of the value of '
        'having the URL.',
  );
}

Future<ProbeOutcome> _tracking(
  ErrorTrackingDemoClient client,
  TrackingProbe probe,
) async {
  final result = await client.run(probe);

  return ProbeOutcome(
    headline: result.reportedRawDioError
        ? 'REGRESSION — the tracker got a bare DioException'
        : 'caught ${result.caught} → '
              '${result.reachesDashboard ? "reported as ${result.reported}" : "filtered as noise"}',
    detail:
        'Trackers group by the exception type, so sending DioException for '
        'everything filed every 500, every 404 and every timeout under one '
        'issue — and left a noise filter no type to key on. The tracker now '
        'receives the mapped ApiException, which is what lets transport noise '
        'be dropped while a real server error is kept.',
  );
}

/// An observation callback that fails must not decide whether the request
/// succeeded.
Future<ProbeOutcome> _brokenSinkIsHarmless() async {
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
    httpClientAdapter: ScriptedAdapter((options) => {'value': 'ok'}),
  );

  try {
    final response = await client.get<dynamic>('/profile');
    return ProbeOutcome(
      headline:
          'HTTP ${response.statusCode} despite $attempts failed '
          'log write${attempts == 1 ? "" : "s"}',
      detail:
          'Before 4.1.0 this returned an ApiException: a log sink, an '
          'analytics backend or a span starter having a bad minute failed the '
          'business request it was only supposed to observe.',
    );
  } on ApiException catch (e) {
    return ProbeOutcome(
      headline: 'REGRESSION — the log sink broke the request',
      detail: '${e.runtimeType}: ${e.message}',
    );
  }
}
