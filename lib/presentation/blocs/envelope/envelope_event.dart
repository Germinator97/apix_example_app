import 'package:equatable/equatable.dart';

abstract class EnvelopeEvent extends Equatable {
  const EnvelopeEvent();

  @override
  List<Object?> get props => [];
}

/// `getAndDecodeData` — single object inside `{payload: {...}}`.
class FetchEnvelopeUser extends EnvelopeEvent {
  final int id;
  const FetchEnvelopeUser(this.id);

  @override
  List<Object?> get props => [id];
}

/// `getListAndDecodeData` — list of objects.
class FetchEnvelopeUsers extends EnvelopeEvent {
  const FetchEnvelopeUsers();
}

/// `getListAndParseData` — list of primitives.
class FetchEnvelopeRoles extends EnvelopeEvent {
  const FetchEnvelopeRoles();
}

/// `postAndDecodeData` — POST with envelope response.
class CreateEnvelopeUser extends EnvelopeEvent {
  final String name;
  const CreateEnvelopeUser(this.name);

  @override
  List<Object?> get props => [name];
}
