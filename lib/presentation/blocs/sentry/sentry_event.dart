import 'package:equatable/equatable.dart';

abstract class SentryTestEvent extends Equatable {
  const SentryTestEvent();

  @override
  List<Object?> get props => [];
}

class TriggerTestError extends SentryTestEvent {
  const TriggerTestError();
}

class TriggerTimeout extends SentryTestEvent {
  const TriggerTimeout();
}

class TriggerNotFound extends SentryTestEvent {
  const TriggerNotFound();
}

class TriggerUnauthorized extends SentryTestEvent {
  const TriggerUnauthorized();
}

class TriggerRealApiError extends SentryTestEvent {
  const TriggerRealApiError();
}

class CaptureManualException extends SentryTestEvent {
  final String message;

  const CaptureManualException(this.message);

  @override
  List<Object?> get props => [message];
}
