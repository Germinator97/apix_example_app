import 'package:apix/apix.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/error_tracking_demo_client.dart';

abstract class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object?> get props => [];
}

/// Sends one failure through the real interceptor chain to the tracker.
class RunTrackingProbe extends TrackingEvent {
  const RunTrackingProbe(this.probe);

  final TrackingProbe probe;

  @override
  List<Object?> get props => [probe];
}

abstract class TrackingState extends Equatable {
  const TrackingState();

  @override
  List<Object?> get props => [];
}

class TrackingInitial extends TrackingState {
  const TrackingInitial();
}

class TrackingRunning extends TrackingState {
  const TrackingRunning(this.probe);

  final TrackingProbe probe;

  @override
  List<Object?> get props => [probe];
}

class TrackingMeasured extends TrackingState {
  const TrackingMeasured(this.result);

  final TrackingProbeResult result;

  @override
  List<Object?> get props => [result.probe, result.caught, result.reported];
}

class TrackingUnexpected extends TrackingState {
  const TrackingUnexpected({required this.probe, required this.reason});

  final TrackingProbe probe;
  final String reason;

  @override
  List<Object?> get props => [probe, reason];
}

/// Drives the error-tracking demo (apix 3.0.0).
///
/// Flags the two outcomes that would mean the 3.0.0 contract is broken: a raw
/// `DioException` handed to the tracker, or a transport failure reported when
/// it should have been filtered as noise.
class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  TrackingBloc({required ErrorTrackingDemoClient client})
    : _client = client,
      super(const TrackingInitial()) {
    on<RunTrackingProbe>(_onRun);
  }

  final ErrorTrackingDemoClient _client;

  Future<void> _onRun(
    RunTrackingProbe event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingRunning(event.probe));
    try {
      final result = await _client.run(event.probe);

      if (result.reportedRawDioError) {
        emit(
          TrackingUnexpected(
            probe: event.probe,
            reason:
                'the tracker got a raw DioException — 3.0.0 should hand over '
                'the mapped ApiException',
          ),
        );
        return;
      }
      emit(TrackingMeasured(result));
    } on ApiException catch (e) {
      emit(
        TrackingUnexpected(
          probe: event.probe,
          reason: 'unexpected ${e.runtimeType}: ${e.message}',
        ),
      );
    }
  }
}
