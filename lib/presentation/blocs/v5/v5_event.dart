import 'package:equatable/equatable.dart';

import '../../../core/services/v5_demo_client.dart';

abstract class V5Event extends Equatable {
  const V5Event();

  @override
  List<Object?> get props => [];
}

/// Runs a single [V5Probe] and reports what it observed.
class RunV5Probe extends V5Event {
  const RunV5Probe(this.probe);

  final V5Probe probe;

  @override
  List<Object?> get props => [probe];
}
