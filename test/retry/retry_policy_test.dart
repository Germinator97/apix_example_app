import 'package:apix_example_app/core/services/retry_policy_demo_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the method-aware retry policy introduced in apix 2.3.0.
///
/// Each test asserts on two levels, and both are needed:
///
/// 1. **The policy** — what `RetryConfig.retryableMethods` actually contains.
/// 2. **The observed behaviour** — how many times the server was really hit.
///
/// Asserting only (2) against `expectedAttemptsFor` would be circular: both
/// sides derive from the same config, so widening `retryableMethods` to
/// include `POST` would move the expectation along with the measurement and
/// the test would stay green while the safety net was gone.
void main() {
  late RetryPolicyDemoClient client;

  setUp(() => client = RetryPolicyDemoClient());

  /// One initial call plus the configured replay budget.
  final retriedAttempts = RetryPolicyDemoClient.retryConfig.maxAttempts + 1;

  group('method-aware retry', () {
    test('GET is idempotent, so a 503 is replayed', () async {
      expect(
        RetryPolicyDemoClient.retryConfig.shouldRetryMethod('GET'),
        isTrue,
        reason: 'GET must stay in retryableMethods (RFC 7231 §4.2.2)',
      );

      final result = await client.run(RetryProbe.idempotentGet);

      expect(result.attempts, retriedAttempts);
      expect(result.wasRetried, isTrue);
      expect(result.matchesPolicy, isTrue);
    });

    test('POST is not idempotent, so a 503 is NOT replayed', () async {
      expect(
        RetryPolicyDemoClient.retryConfig.shouldRetryMethod('POST'),
        isFalse,
        reason:
            'POST must stay OUT of retryableMethods — replaying a write after '
            'a 5xx the server may already have committed duplicates the side '
            'effect (a duplicate order). If this fails, the demo no longer '
            'demonstrates the 2.3.0 guard.',
      );

      final result = await client.run(RetryProbe.nonIdempotentPost);

      expect(
        result.attempts,
        1,
        reason: 'the server must be hit exactly once — no replay',
      );
      expect(result.wasRetried, isFalse);
      expect(result.matchesPolicy, isTrue);
    });

    test('forceRetry() opts a POST back into the replay budget', () async {
      final result = await client.run(RetryProbe.forcedPost);

      expect(result.attempts, retriedAttempts);
      expect(result.wasRetried, isTrue);
      expect(result.matchesPolicy, isTrue);
    });

    test('the opt-in is what separates the two POST probes', () async {
      final plain = await client.run(RetryProbe.nonIdempotentPost);
      final forced = await client.run(RetryProbe.forcedPost);

      expect(
        forced.attempts,
        greaterThan(plain.attempts),
        reason:
            'same method, same status code, same config — only forceRetry() '
            'differs, so it must be the thing that changes the outcome',
      );
    });

    test(
      'forceRetry() overrides the method guard, never maxAttempts',
      () async {
        final result = await client.run(RetryProbe.forcedPost);

        expect(
          result.attempts,
          retriedAttempts,
          reason:
              'forceRetry() must not grant unlimited replays — the attempt '
              'budget still caps it',
        );
      },
    );
  });
}
