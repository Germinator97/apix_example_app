import 'dart:convert';
import 'dart:typed_data';

import 'package:apix/apix.dart';
import 'package:sentry_flutter/sentry_flutter.dart'
    show SentryEvent, SentryException;
import 'package:dio/dio.dart'
    show DioException, Headers, HttpClientAdapter, RequestOptions, ResponseBody;

/// What a probe sends to the error tracker.
enum TrackingProbe {
  /// `500` — a real server error. Reported, and typed `ServerException`.
  serverError,

  /// A dropped connection. Filtered as transport noise, never reported.
  connectionLost,
}

/// Outcome of a probe: what the caller caught, and what was handed to the
/// tracker.
class TrackingProbeResult {
  const TrackingProbeResult({
    required this.probe,
    required this.caught,
    required this.reported,
    required this.filteredAsNoise,
  });

  final TrackingProbe probe;

  /// Type the caller caught, e.g. `ServerException`.
  final String caught;

  /// Type handed to `ErrorTrackingConfig.onError`, or null if the interceptor
  /// did not capture at all.
  final String? reported;

  /// Whether `SentrySetup`'s noise filter would drop it in `beforeSend`.
  final bool filteredAsNoise;

  /// Whether the tracker was handed the raw Dio error rather than a typed one.
  bool get reportedRawDioError => reported == 'DioException';

  /// Whether the event actually lands in the dashboard.
  bool get reachesDashboard => reported != null && !filteredAsNoise;
}

/// Demonstrates what apix hands to an error tracker — the point of the 3.0.0
/// change.
///
/// The client is wired with the **same** `errorTrackingConfig` shape as the
/// real one, so failures travel the actual interceptor chain. Only the
/// transport is mocked, which keeps the demo deterministic and offline.
///
/// Before 3.0.0 both probes below handed the tracker a bare `DioException`:
/// every server error, every 404 and every timeout landed in one issue, and a
/// noise filter had no type to key on. Now the tracker receives the mapped
/// `ApiException`, so a `ServerException` and a `ConnectionException` are told
/// apart — the first is reported, the second is dropped as transport noise.
class ErrorTrackingDemoClient {
  ErrorTrackingDemoClient() {
    _client = ApiClientFactory.create(
      baseUrl: 'https://tracking.demo.local',
      loggerConfig: LoggerConfig.minimal(),
      httpClientAdapter: _TrackingMockAdapter(),
      errorTrackingConfig: ErrorTrackingConfig(
        environment: 'development',
        // Records what apix hands over, then forwards to Sentry exactly as the
        // real client does — so the dashboard shows the same thing the UI
        // reports.
        onError:
            (
              Object exception, {
              StackTrace? stackTrace,
              Map<String, dynamic>? extra,
              Map<String, String>? tags,
            }) async {
              _lastReported = exception.runtimeType.toString();
              // Reporting is stage one; the noise filter in `beforeSend` is
              // stage two. Asking it here shows which of the two decided the
              // outcome — the interceptor captures every non-HTTP failure, so
              // a dropped connection does reach this callback and is only
              // discarded afterwards.
              _lastFiltered = SentrySetup.isNetworkNoiseError(
                SentryEvent(
                  exceptions: [
                    SentryException(
                      type: exception.runtimeType.toString(),
                      value: exception.toString(),
                      throwable: exception,
                    ),
                  ],
                ),
              );
              await SentrySetup.captureException(
                exception,
                stackTrace: stackTrace,
                extra: extra,
                tags: tags,
              );
            },
        onBreadcrumb: SentrySetup.addBreadcrumbFromMap,
      ),
    );
  }

  late final ApiClient _client;

  String? _lastReported;
  bool _lastFiltered = false;

  /// Runs [probe] and reports what the caller caught and what the tracker got.
  Future<TrackingProbeResult> run(TrackingProbe probe) async {
    _lastReported = null;
    _lastFiltered = false;
    final path = switch (probe) {
      TrackingProbe.serverError => '/server-error',
      TrackingProbe.connectionLost => '/offline',
    };

    var caught = 'none';
    try {
      await _client.get<dynamic>(path);
    } on ApiException catch (e) {
      caught = e.runtimeType.toString();
    }

    return TrackingProbeResult(
      probe: probe,
      caught: caught,
      reported: _lastReported,
      filteredAsNoise: _lastFiltered,
    );
  }
}

/// Answers a `500` on `/server-error`, and drops the connection on `/offline`.
class _TrackingMockAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    if (options.path == '/offline') {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Network is unreachable',
      );
    }
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'message': 'Upstream exploded'})),
      500,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
