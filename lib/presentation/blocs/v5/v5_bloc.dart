import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/v5_demo_client.dart';
import 'v5_event.dart';
import 'v5_state.dart';

/// Drives the apix 5.0.0 demos.
///
/// Where the 4.x probes answered an integration report, these answer an audit —
/// six defects that produced a *wrong answer* rather than an error. Each probe
/// shows the evidence that was missing: the body the second account received,
/// the fields that reached the wire, the flag metrics recorded.
class V5Bloc extends Bloc<V5Event, V5State> {
  V5Bloc({required V5DemoClient client})
    : _client = client,
      super(const V5Initial()) {
    on<RunV5Probe>(_onRunProbe);
  }

  final V5DemoClient _client;

  Future<void> _onRunProbe(RunV5Probe event, Emitter<V5State> emit) async {
    emit(V5Running(event.probe));
    try {
      emit(V5Measured(await _client.run(event.probe)));
    } catch (e) {
      // Every handler calling async code needs this: without it a throwing
      // probe is a silent crash, and the screen keeps showing the last result
      // as if nothing happened.
      emit(V5Failed(probe: event.probe, reason: '${e.runtimeType}: $e'));
    }
  }
}
