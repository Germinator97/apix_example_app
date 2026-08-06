import 'package:equatable/equatable.dart';

import '../../../core/services/retry_policy_demo_client.dart';

abstract class RetryPolicyEvent extends Equatable {
  const RetryPolicyEvent();

  @override
  List<Object?> get props => [];
}

/// Measures how many times the server is hit for a given [RetryProbe].
class RunRetryProbe extends RetryPolicyEvent {
  const RunRetryProbe(this.probe);

  final RetryProbe probe;

  @override
  List<Object?> get props => [probe];
}
