import 'package:equatable/equatable.dart';

import '../../../core/services/retry_policy_demo_client.dart';

abstract class RetryPolicyState extends Equatable {
  const RetryPolicyState();

  @override
  List<Object?> get props => [];
}

class RetryPolicyInitial extends RetryPolicyState {
  const RetryPolicyInitial();
}

class RetryPolicyRunning extends RetryPolicyState {
  const RetryPolicyRunning(this.probe);

  final RetryProbe probe;

  @override
  List<Object?> get props => [probe];
}

/// The probe ran and the attempt count matched the configured policy.
class RetryPolicyMeasured extends RetryPolicyState {
  const RetryPolicyMeasured(this.result);

  final RetryProbeResult result;

  @override
  List<Object?> get props => [
    result.probe,
    result.attempts,
    result.expectedAttempts,
  ];
}

/// The attempt count contradicts the configured policy, or the probe blew up.
///
/// Surfacing this as its own state keeps the demo from quietly reporting a
/// number that no longer means what the label says.
class RetryPolicyUnexpected extends RetryPolicyState {
  const RetryPolicyUnexpected({required this.probe, required this.reason});

  final RetryProbe probe;
  final String reason;

  @override
  List<Object?> get props => [probe, reason];
}
