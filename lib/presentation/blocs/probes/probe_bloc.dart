import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/probes/demo_probe.dart';

/// Runs a [DemoProbe] and reports what it observed.
class RunProbe extends Equatable {
  const RunProbe(this.probe);

  final DemoProbe probe;

  @override
  List<Object?> get props => [probe.id];
}

abstract class ProbeState extends Equatable {
  const ProbeState();

  @override
  List<Object?> get props => [];
}

class ProbeIdle extends ProbeState {
  const ProbeIdle();
}

class ProbeRunning extends ProbeState {
  const ProbeRunning(this.probe);

  final DemoProbe probe;

  @override
  List<Object?> get props => [probe.id];
}

class ProbeMeasured extends ProbeState {
  const ProbeMeasured({required this.probe, required this.outcome});

  final DemoProbe probe;
  final ProbeOutcome outcome;

  @override
  List<Object?> get props => [probe.id, outcome.headline, outcome.detail];
}

/// The probe threw instead of reporting. Its own state, so a demo that breaks
/// says so rather than silently showing the previous result.
class ProbeFailed extends ProbeState {
  const ProbeFailed({required this.probe, required this.reason});

  final DemoProbe probe;
  final String reason;

  @override
  List<Object?> get props => [probe.id, reason];
}

/// Drives every demonstration in the app.
///
/// One bloc for all of them, because there was never anything version-specific
/// about running a probe and reporting its outcome — only the probe bodies
/// differed. Five blocs (`V4Bloc`, `V5Bloc`, `Epic11Bloc`, `RetryPolicyBloc`,
/// `TrackingBloc`) carried five copies of this same emit-run-catch shape, and
/// each release added a sixth.
class ProbeBloc extends Bloc<RunProbe, ProbeState> {
  ProbeBloc() : super(const ProbeIdle()) {
    on<RunProbe>(_onRun);
  }

  Future<void> _onRun(RunProbe event, Emitter<ProbeState> emit) async {
    emit(ProbeRunning(event.probe));
    try {
      emit(ProbeMeasured(probe: event.probe, outcome: await event.probe.run()));
    } catch (e) {
      // Every handler calling async code needs this: without it a throwing
      // probe is a silent crash, and the screen keeps showing the last result
      // as if nothing happened.
      emit(ProbeFailed(probe: event.probe, reason: '${e.runtimeType}: $e'));
    }
  }
}
