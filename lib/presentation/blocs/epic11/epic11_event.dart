import 'package:equatable/equatable.dart';

abstract class Epic11Event extends Equatable {
  const Epic11Event();

  @override
  List<Object?> get props => [];
}

class TriggerParsingException extends Epic11Event {
  const TriggerParsingException();
}

class TriggerCaptivePortal extends Epic11Event {
  const TriggerCaptivePortal();
}

class TriggerBusinessError extends Epic11Event {
  const TriggerBusinessError();
}

class TriggerRetryAfter extends Epic11Event {
  const TriggerRetryAfter();
}

class TriggerTokenProviderFailure extends Epic11Event {
  const TriggerTokenProviderFailure();
}
