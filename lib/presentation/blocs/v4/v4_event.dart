import 'package:equatable/equatable.dart';

import '../../../core/services/v4_demo_client.dart';

abstract class V4Event extends Equatable {
  const V4Event();

  @override
  List<Object?> get props => [];
}

/// Runs a single [V4Probe] and reports what it observed.
class RunV4Probe extends V4Event {
  const RunV4Probe(this.probe);

  final V4Probe probe;

  @override
  List<Object?> get props => [probe];
}
