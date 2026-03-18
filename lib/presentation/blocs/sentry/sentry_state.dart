import 'package:equatable/equatable.dart';

abstract class SentryState extends Equatable {
  const SentryState();

  @override
  List<Object?> get props => [];
}

class SentryInitial extends SentryState {
  const SentryInitial();
}

class SentryTesting extends SentryState {
  final String testName;

  const SentryTesting(this.testName);

  @override
  List<Object?> get props => [testName];
}

class SentryErrorCaptured extends SentryState {
  final String errorType;
  final String message;

  const SentryErrorCaptured({required this.errorType, required this.message});

  @override
  List<Object?> get props => [errorType, message];
}

class SentryTestFailed extends SentryState {
  final String reason;

  const SentryTestFailed(this.reason);

  @override
  List<Object?> get props => [reason];
}
