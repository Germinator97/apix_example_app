import 'package:apix/apix.dart';
import 'package:apix_example_app/core/services/retry_policy_demo_client.dart';
import 'package:apix_example_app/presentation/blocs/retry_policy/retry_policy_bloc.dart';
import 'package:apix_example_app/presentation/blocs/retry_policy/retry_policy_event.dart';
import 'package:apix_example_app/presentation/blocs/retry_policy/retry_policy_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements RetryPolicyDemoClient {}

void main() {
  late _MockClient client;

  RetryPolicyBloc build() => RetryPolicyBloc(client: client);

  setUp(() => client = _MockClient());

  /// Un relevé conforme à la politique configurée.
  RetryProbeResult conforme(RetryProbe probe) => RetryProbeResult(
    probe: probe,
    attempts: RetryPolicyDemoClient.expectedAttemptsFor(probe),
    expectedAttempts: RetryPolicyDemoClient.expectedAttemptsFor(probe),
  );

  blocTest<RetryPolicyBloc, RetryPolicyState>(
    'émet [Running, Measured] quand le relevé respecte la politique',
    setUp: () {
      when(
        () => client.run(RetryProbe.nonIdempotentPost),
      ).thenAnswer((_) async => conforme(RetryProbe.nonIdempotentPost));
    },
    build: build,
    act: (bloc) => bloc.add(const RunRetryProbe(RetryProbe.nonIdempotentPost)),
    expect: () => [
      const RetryPolicyRunning(RetryProbe.nonIdempotentPost),
      RetryPolicyMeasured(conforme(RetryProbe.nonIdempotentPost)),
    ],
  );

  blocTest<RetryPolicyBloc, RetryPolicyState>(
    'émet [Running, Unexpected] si le POST a été rejoué malgré la politique',
    setUp: () {
      // Le défaut d'avant 2.3.0 : le POST est rejoué. Le compte mesuré
      // contredit alors ce que la config implique.
      when(() => client.run(RetryProbe.nonIdempotentPost)).thenAnswer(
        (_) async => const RetryProbeResult(
          probe: RetryProbe.nonIdempotentPost,
          attempts: 3,
          expectedAttempts: 1,
        ),
      );
    },
    build: build,
    act: (bloc) => bloc.add(const RunRetryProbe(RetryProbe.nonIdempotentPost)),
    expect: () => [
      const RetryPolicyRunning(RetryProbe.nonIdempotentPost),
      isA<RetryPolicyUnexpected>().having(
        (s) => s.reason,
        'reason',
        allOf(contains('3x'), contains('1x')),
      ),
    ],
  );

  blocTest<RetryPolicyBloc, RetryPolicyState>(
    'émet [Running, Unexpected] si la sonde lève une exception inattendue',
    setUp: () {
      when(
        () => client.run(RetryProbe.idempotentGet),
      ).thenThrow(const NotFoundException(message: 'no route'));
    },
    build: build,
    act: (bloc) => bloc.add(const RunRetryProbe(RetryProbe.idempotentGet)),
    expect: () => [
      const RetryPolicyRunning(RetryProbe.idempotentGet),
      isA<RetryPolicyUnexpected>().having(
        (s) => s.reason,
        'reason',
        contains('NotFoundException'),
      ),
    ],
  );
}
