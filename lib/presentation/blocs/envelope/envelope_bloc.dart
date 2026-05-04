import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/envelope_demo_client.dart';
import 'envelope_event.dart';
import 'envelope_state.dart';

class EnvelopeBloc extends Bloc<EnvelopeEvent, EnvelopeState> {
  final EnvelopeDemoClient _client;

  EnvelopeBloc({required EnvelopeDemoClient client})
    : _client = client,
      super(const EnvelopeInitial()) {
    on<FetchEnvelopeUser>(_onFetchUser);
    on<FetchEnvelopeUsers>(_onFetchUsers);
    on<FetchEnvelopeRoles>(_onFetchRoles);
    on<CreateEnvelopeUser>(_onCreateUser);
  }

  Future<void> _onFetchUser(
    FetchEnvelopeUser event,
    Emitter<EnvelopeState> emit,
  ) async {
    const op = 'getAndDecodeData';
    emit(const EnvelopeLoading(op));
    try {
      final user = await _client.fetchEnvelopeUser(event.id);
      emit(
        EnvelopeResult(
          operation: op,
          summary:
              'id=${user['id']} name="${user['name']}" '
              'email=${user['email']}',
        ),
      );
    } catch (e) {
      emit(EnvelopeError(operation: op, message: e.toString()));
    }
  }

  Future<void> _onFetchUsers(
    FetchEnvelopeUsers event,
    Emitter<EnvelopeState> emit,
  ) async {
    const op = 'getListAndDecodeData';
    emit(const EnvelopeLoading(op));
    try {
      final users = await _client.fetchEnvelopeUsers();
      emit(
        EnvelopeResult(
          operation: op,
          summary:
              '${users.length} users → '
              '${users.map((u) => u['name']).join(', ')}',
        ),
      );
    } catch (e) {
      emit(EnvelopeError(operation: op, message: e.toString()));
    }
  }

  Future<void> _onFetchRoles(
    FetchEnvelopeRoles event,
    Emitter<EnvelopeState> emit,
  ) async {
    const op = 'getListAndParseData';
    emit(const EnvelopeLoading(op));
    try {
      final roles = await _client.fetchRoles();
      emit(
        EnvelopeResult(operation: op, summary: 'roles → ${roles.join(', ')}'),
      );
    } catch (e) {
      emit(EnvelopeError(operation: op, message: e.toString()));
    }
  }

  Future<void> _onCreateUser(
    CreateEnvelopeUser event,
    Emitter<EnvelopeState> emit,
  ) async {
    const op = 'postAndDecodeData';
    emit(const EnvelopeLoading(op));
    try {
      final created = await _client.createEnvelopeUser(name: event.name);
      emit(
        EnvelopeResult(
          operation: op,
          summary: 'created id=${created['id']} name="${created['name']}"',
        ),
      );
    } catch (e) {
      emit(EnvelopeError(operation: op, message: e.toString()));
    }
  }
}
