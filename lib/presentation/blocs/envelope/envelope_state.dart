import 'package:equatable/equatable.dart';

abstract class EnvelopeState extends Equatable {
  const EnvelopeState();

  @override
  List<Object?> get props => [];
}

class EnvelopeInitial extends EnvelopeState {
  const EnvelopeInitial();
}

class EnvelopeLoading extends EnvelopeState {
  final String operation;
  const EnvelopeLoading(this.operation);

  @override
  List<Object?> get props => [operation];
}

class EnvelopeResult extends EnvelopeState {
  final String operation;
  final String summary;
  const EnvelopeResult({required this.operation, required this.summary});

  @override
  List<Object?> get props => [operation, summary];
}

class EnvelopeError extends EnvelopeState {
  final String operation;
  final String message;
  const EnvelopeError({required this.operation, required this.message});

  @override
  List<Object?> get props => [operation, message];
}
