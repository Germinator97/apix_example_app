import 'package:apix/apix.dart';

import '../services/retry_policy_demo_client.dart';
import '../services/robustness_demo_client.dart';
import 'demo_probe.dart';

/// When apix replays a request, and when it deliberately does not.
///
/// Every route in these scenarios answers `503`, which *is* retryable — so the
/// only thing deciding a replay is the HTTP method, plus an explicit opt-in for
/// the non-idempotent ones. Replaying a `POST` that the server already
/// committed is how an order gets placed twice.
List<DemoProbe> retryProbes(
  RetryPolicyDemoClient retry,
  RobustnessDemoClient robustness,
) => [
  DemoProbe(
    id: 'retry.idempotent_get',
    theme: ProbeTheme.retry,
    label: 'GET (idempotent) → replayed',
    run: () => _policy(retry, RetryProbe.idempotentGet),
  ),
  DemoProbe(
    id: 'retry.non_idempotent_post',
    theme: ProbeTheme.retry,
    label: 'POST → not replayed',
    run: () => _policy(retry, RetryProbe.nonIdempotentPost),
  ),
  DemoProbe(
    id: 'retry.forced_post',
    theme: ProbeTheme.retry,
    label: 'POST + forceRetry()',
    run: () => _policy(retry, RetryProbe.forcedPost),
  ),
  DemoProbe(
    id: 'retry.retry_after_honored',
    theme: ProbeTheme.retry,
    label: 'Retry-After honoured',
    run: () => _retryAfter(robustness),
  ),
];

Future<ProbeOutcome> _policy(
  RetryPolicyDemoClient client,
  RetryProbe probe,
) async {
  final result = await client.run(probe);

  return ProbeOutcome(
    headline: result.matchesPolicy
        ? '${result.attempts} attempt${result.attempts == 1 ? "" : "s"} — '
              '${result.wasRetried ? "replayed" : "not replayed"}, as the '
              'policy says'
        : 'REGRESSION — ${result.attempts} attempts, expected '
              '${result.expectedAttempts}',
    detail:
        'Every route answers 503, so the status cannot be what decides. Only '
        'the method does — and for a non-idempotent one, an explicit '
        'forceRetry(). Before 2.3.0 a POST returning 5xx *after* the server '
        'had committed was replayed, duplicating the side effect.',
  );
}

Future<ProbeOutcome> _retryAfter(RobustnessDemoClient client) async {
  try {
    final elapsed = await client.triggerRetryAfter();
    return ProbeOutcome(
      headline: 'Waited ${elapsed}ms before replaying (expected ≥1000ms)',
      detail:
          'The server named a delay through Retry-After and apix waited it, '
          'rather than applying its own backoff. A server-named delay is never '
          'jittered: when the server says when to come back, obeying it '
          'exactly matters more than spreading load.',
    );
  } on ApiException catch (e) {
    return ProbeOutcome(
      headline: 'REGRESSION — the Retry-After demo failed',
      detail: '${e.runtimeType}: ${e.message}',
    );
  }
}
