import 'package:apix/apix.dart';

import '../services/robustness_demo_client.dart';
import 'demo_probe.dart';
import 'scripted_adapter.dart';

/// How a failure reaches the caller, and what it is called when it does.
///
/// The recurring theme: a status is not a business code, and a `200` is not
/// necessarily a success.
List<DemoProbe> errorProbes(RobustnessDemoClient robustness) => [
  DemoProbe(
    id: 'errors.application_code',
    theme: ProbeTheme.errors,
    label: 'Application error code (409)',
    run: _applicationErrorCode,
  ),
  DemoProbe(
    id: 'errors.status_is_not_a_code',
    theme: ProbeTheme.errors,
    label: 'A status is not a code',
    run: _statusIsNotACode,
  ),
  DemoProbe(
    id: 'errors.rate_limited',
    theme: ProbeTheme.errors,
    label: 'Rate limit (429) with a delay',
    run: _rateLimited,
  ),
  DemoProbe(
    id: 'errors.business_failure_in_200',
    theme: ProbeTheme.errors,
    label: '200 + success:false is a failure',
    run: _businessFailureIn200,
  ),
  DemoProbe(
    id: 'errors.json_error_on_download',
    theme: ProbeTheme.errors,
    label: 'A download\'s JSON error keeps its code',
    run: _jsonErrorOnDownload,
  ),
  DemoProbe(
    id: 'errors.bare_array',
    theme: ProbeTheme.errors,
    label: 'A bare [] is an empty list',
    run: _bareArray,
  ),
  DemoProbe(
    id: 'errors.parsing',
    theme: ProbeTheme.errors,
    label: 'ParsingException',
    run: () => _expect<ParsingException>(
      robustness.triggerParsingFailure,
      describe: (e) => e.message,
      detail:
          'A malformed body reaches the caller as ParsingException rather than '
          'the raw TypeError the fromJson callback threw.',
    ),
  ),
  DemoProbe(
    id: 'errors.captive_portal',
    theme: ProbeTheme.errors,
    label: 'Captive portal (wrong Content-Type)',
    run: () => _expect<UnexpectedContentTypeException>(
      robustness.triggerCaptivePortal,
      describe: (e) =>
          'expected ${e.expectedContentType}, got ${e.actualContentType ?? "(none)"}',
      detail:
          'A hotel Wi-Fi portal answering HTML with a 200 is caught before it '
          'is funnelled into fromJson and surfaces as a confusing parse error.',
    ),
  ),
  DemoProbe(
    id: 'errors.response_validator',
    theme: ProbeTheme.errors,
    label: 'responseValidator → BusinessException',
    run: () => _expect<BusinessException>(
      robustness.triggerBusinessError,
      describe: (e) => '[${e.code}] ${e.message}',
      detail:
          'A legacy API reporting business errors through HTTP 200 is turned '
          'into the same typed exception flow as an HTTP failure.',
    ),
  ),
];

/// Runs [call] expecting it to throw [E], and reports what was caught.
///
/// Shared because five probes had the same three-branch shape — expected type,
/// unexpected type, unexpected success — copied into a bloc handler each time.
/// The success branch matters: without it a demo whose scenario stopped
/// failing would report nothing and look fine.
Future<ProbeOutcome> _expect<E extends ApiException>(
  Future<void> Function() call, {
  required String Function(E error) describe,
  required String detail,
}) async {
  try {
    await call();
    return ProbeOutcome(
      headline: 'Unexpected success — expected $E',
      detail: 'the scenario is supposed to fail; it did not',
    );
  } on E catch (e) {
    return ProbeOutcome(headline: 'Caught $E → ${describe(e)}', detail: detail);
  } on ApiException catch (e) {
    return ProbeOutcome(
      headline: 'REGRESSION — got ${e.runtimeType}, expected $E',
      detail: e.message,
    );
  }
}

Future<ProbeOutcome> _applicationErrorCode() async {
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    httpClientAdapter: ScriptedAdapter(
      (options) => const ScriptedResponse({
        'code': 'OUT_OF_STOCK',
        'message': 'Article indisponible pour cette commande.',
      }, statusCode: 409),
    ),
  );

  try {
    await client.post<void>('/orders', data: {'quantity': 3});
    return const ProbeOutcome(
      headline: 'Unexpected success',
      detail: 'the stub always answers 409',
    );
  } on ApiException catch (e) {
    // The point of the switch: it keeps working if the backend moves this case
    // from 409 to 422 tomorrow. A statusCode branch would not.
    final reaction = switch (e.code) {
      'OUT_OF_STOCK' => 'Proposer une alternative',
      'OPERATION_NOT_RETRYABLE' => 'Refus définitif',
      _ => 'Message générique',
    };
    return ProbeOutcome(
      headline: 'code=${e.code} → $reaction',
      detail:
          'HTTP ${e.statusCode} — the status could drift, the code will not. '
          'Before 4.0.0 this meant digging through responseBody by hand.',
    );
  }
}

Future<ProbeOutcome> _jsonErrorOnDownload() async {
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    httpClientAdapter: ScriptedAdapter(
      (options) => const ScriptedResponse({
        'code': 'EXPORT_TOO_LARGE',
        'message': 'Export trop volumineux : réduisez la sélection.',
      }, statusCode: 400),
    ),
  );

  try {
    await client.getAndReadBytes('/reports/2026-08');
    return const ProbeOutcome(
      headline: 'Unexpected success',
      detail: 'the stub always answers 400',
    );
  } on ApiException catch (e) {
    return ProbeOutcome(
      headline: e.code == null
          ? 'REGRESSION — "${e.message}", no code'
          : 'code=${e.code} → ${e.message}',
      detail:
          'The call asked for bytes, and dio hands an error body over in the '
          'form the request asked for. The JSON is read all the same: a '
          'failed download used to report "HTTP 400" and no code.',
    );
  }
}

Future<ProbeOutcome> _statusIsNotACode() async {
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    httpClientAdapter: ScriptedAdapter(
      (options) => const ScriptedResponse({
        'code': 401,
        'status': 'error',
        'message': 'Authentification requise. Veuillez vous connecter.',
      }, statusCode: 401),
    ),
  );

  try {
    await client.get<dynamic>('/profile');
    return const ProbeOutcome(
      headline: 'Unexpected success',
      detail: 'the stub always answers 401',
    );
  } on ApiException catch (e) {
    return ProbeOutcome(
      headline: e.code != null
          ? 'REGRESSION — code=${e.code} is just the status'
          : 'code=null, statusCode=${e.statusCode} — the status stayed where '
                'it belongs',
      detail:
          'This envelope is one a real backend actually returns. Read as-is it '
          'made a switch (e.code) look like business logic while keying on a '
          'status that drifts between server revisions. A real code (4001 '
          'under a 400) still comes through.',
    );
  }
}

Future<ProbeOutcome> _rateLimited() async {
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    httpClientAdapter: ScriptedAdapter(
      (options) => const ScriptedResponse(
        {'message': 'Too many requests'},
        statusCode: 429,
        headers: {
          'retry-after': ['45'],
        },
      ),
    ),
  );

  try {
    await client.get<void>('/reports');
    return const ProbeOutcome(
      headline: 'Unexpected success',
      detail: 'the stub always answers 429',
    );
  } on TooManyRequestsException catch (e) {
    final wait = e.retryAfter;
    return ProbeOutcome(
      headline: wait == null
          ? 'Réessayez plus tard (délai inconnu)'
          : 'Réessayez dans ${wait.inSeconds} s',
      detail:
          'Caught as TooManyRequestsException, a subtype of ClientException, '
          'so existing catch clauses still match. Before 4.0.0 the Retry-After '
          'value was parsed and dropped.',
    );
  }
}

Future<ProbeOutcome> _businessFailureIn200() async {
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
    httpClientAdapter: ScriptedAdapter(
      (options) => {'success': false, 'message': 'Commande refusée.'},
    ),
  );

  var refused = false;
  try {
    await client.get<dynamic>('/orders');
  } on ApiException {
    refused = true;
  }

  final counted = measured.isEmpty ? null : measured.first.success;

  return ProbeOutcome(
    headline: counted == false
        ? 'Refused, and measured success=false'
        : 'REGRESSION — measured success=$counted',
    detail:
        'The validator ran after the cache and after every observer, so the '
        'refused body was cached — and a cache hit skips response '
        'interceptors, so it came back unvalidated, as a success. Metrics had '
        'already recorded success=true: the dashboards counted as fine the '
        'exact failures this feature exists to surface. (refused=$refused)',
  );
}

Future<ProbeOutcome> _bareArray() async {
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    httpClientAdapter: ScriptedAdapter((options) => <dynamic>[]),
  );

  try {
    final rows = await client.getListAndDecodeDataOrEmpty<Map<String, dynamic>>(
      '/reports',
      (json) => json,
    );
    return ProbeOutcome(
      headline: 'Got ${rows.length} rows — no crash',
      detail:
          'Backends serialise an empty collection as [] rather than '
          '{"data": []}, and the unwrapper rejected it — so the methods whose '
          'whole purpose is tolerating "no data" broke on the commonest '
          'spelling of it, under HTTP 200, on the user who had nothing yet.',
    );
  } on ApiException catch (e) {
    return ProbeOutcome(
      headline: 'REGRESSION — a bare [] still throws',
      detail: '${e.runtimeType}: ${e.message}',
    );
  }
}
