import 'package:apix/apix.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/retry_policy_demo_client.dart';
import 'retry_policy_event.dart';
import 'retry_policy_state.dart';

/// Drives the method-aware retry demo (apix 2.3.0).
///
/// Each probe reports the number of times the server was hit. The bloc
/// compares that count with what [RetryPolicyDemoClient.retryConfig] implies
/// and emits [RetryPolicyUnexpected] on any mismatch, so a regression in the
/// retry policy shows up in the UI instead of hiding behind a plausible
/// number.
class RetryPolicyBloc extends Bloc<RetryPolicyEvent, RetryPolicyState> {
  RetryPolicyBloc({required RetryPolicyDemoClient client})
    : _client = client,
      super(const RetryPolicyInitial()) {
    on<RunRetryProbe>(_onRunProbe);
  }

  final RetryPolicyDemoClient _client;

  Future<void> _onRunProbe(
    RunRetryProbe event,
    Emitter<RetryPolicyState> emit,
  ) async {
    emit(RetryPolicyRunning(event.probe));
    try {
      final result = await _client.run(event.probe);
      if (!result.matchesPolicy) {
        emit(
          RetryPolicyUnexpected(
            probe: event.probe,
            reason:
                'server hit ${result.attempts}x, policy implies '
                '${result.expectedAttempts}x',
          ),
        );
        return;
      }
      emit(RetryPolicyMeasured(result));
    } on ApiException catch (e) {
      emit(
        RetryPolicyUnexpected(
          probe: event.probe,
          reason: 'unexpected ${e.runtimeType}: ${e.message}',
        ),
      );
    }
  }
}
