import 'package:equatable/equatable.dart';

abstract class Epic11State extends Equatable {
  const Epic11State();

  @override
  List<Object?> get props => [];
}

class Epic11Initial extends Epic11State {
  const Epic11Initial();
}

class Epic11Running extends Epic11State {
  final String scenario;
  const Epic11Running(this.scenario);

  @override
  List<Object?> get props => [scenario];
}

/// The expected typed exception was raised — demo succeeded.
class Epic11Captured extends Epic11State {
  final String scenario;
  final String exceptionType;
  final String message;
  final int? elapsedMs;

  const Epic11Captured({
    required this.scenario,
    required this.exceptionType,
    required this.message,
    this.elapsedMs,
  });

  @override
  List<Object?> get props => [scenario, exceptionType, message, elapsedMs];
}

/// The retry-after demo: the call succeeded after waiting; we report the
/// wall-clock to prove the header was honoured.
class Epic11RetryAfterSucceeded extends Epic11State {
  final int elapsedMs;
  const Epic11RetryAfterSucceeded(this.elapsedMs);

  @override
  List<Object?> get props => [elapsedMs];
}

/// Sanity check failure: the demo expected an exception but the call
/// succeeded (or threw an unexpected type).
class Epic11Unexpected extends Epic11State {
  final String scenario;
  final String reason;
  const Epic11Unexpected({required this.scenario, required this.reason});

  @override
  List<Object?> get props => [scenario, reason];
}
