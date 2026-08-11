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
];

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
