import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/v4_demo_client.dart';
import 'v4_event.dart';
import 'v4_state.dart';

/// Drives the apix 4.0.0 demos.
///
/// Each probe answers one of the gaps the consumer integration report
/// raised: an error code the consumer could not reach, a Retry-After that was
/// parsed and dropped, deduplication welded to the cache, and a strategy that
/// wrote what it would never read.
class V4Bloc extends Bloc<V4Event, V4State> {
  V4Bloc({required V4DemoClient client})
    : _client = client,
      super(const V4Initial()) {
    on<RunV4Probe>(_onRunProbe);
  }

  final V4DemoClient _client;

  Future<void> _onRunProbe(RunV4Probe event, Emitter<V4State> emit) async {
    emit(V4Running(event.probe));
    try {
      emit(V4Measured(await _client.run(event.probe)));
    } catch (e) {
      // Every handler calling async code needs this: without it a throwing
      // probe is a silent crash, and the screen keeps showing the last
      // result as if nothing happened.
      emit(V4Failed(probe: event.probe, reason: '${e.runtimeType}: $e'));
    }
  }
}
