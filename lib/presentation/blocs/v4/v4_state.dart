import 'package:equatable/equatable.dart';

import '../../../core/services/v4_demo_client.dart';

abstract class V4State extends Equatable {
  const V4State();

  @override
  List<Object?> get props => [];
}

class V4Initial extends V4State {
  const V4Initial();
}

class V4Running extends V4State {
  const V4Running(this.probe);

  final V4Probe probe;

  @override
  List<Object?> get props => [probe];
}

class V4Measured extends V4State {
  const V4Measured(this.result);

  final V4ProbeResult result;

  @override
  List<Object?> get props => [result.probe, result.headline, result.detail];
}

/// The probe threw instead of reporting. Its own state, so a demo that breaks
/// says so rather than silently showing the previous result.
class V4Failed extends V4State {
  const V4Failed({required this.probe, required this.reason});

  final V4Probe probe;
  final String reason;

  @override
  List<Object?> get props => [probe, reason];
}
