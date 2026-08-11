import 'package:equatable/equatable.dart';

import '../../../core/services/v5_demo_client.dart';

abstract class V5State extends Equatable {
  const V5State();

  @override
  List<Object?> get props => [];
}

class V5Initial extends V5State {
  const V5Initial();
}

class V5Running extends V5State {
  const V5Running(this.probe);

  final V5Probe probe;

  @override
  List<Object?> get props => [probe];
}

class V5Measured extends V5State {
  const V5Measured(this.result);

  final V5ProbeResult result;

  @override
  List<Object?> get props => [result.probe, result.headline, result.detail];
}

/// The probe threw instead of reporting. Its own state, so a demo that breaks
/// says so rather than silently showing the previous result.
class V5Failed extends V5State {
  const V5Failed({required this.probe, required this.reason});

  final V5Probe probe;
  final String reason;

  @override
  List<Object?> get props => [probe, reason];
}
