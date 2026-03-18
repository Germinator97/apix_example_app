import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/get_users.dart';
import 'users_event.dart';
import 'users_state.dart';

class UsersBloc extends Bloc<UsersEvent, UsersState> {
  final GetUsers _getUsers;

  UsersBloc({required GetUsers getUsers})
    : _getUsers = getUsers,
      super(const UsersInitial()) {
    on<FetchUsers>(_onFetchUsers);
    on<RefreshUsers>(_onRefreshUsers);
  }

  Future<void> _onFetchUsers(FetchUsers event, Emitter<UsersState> emit) async {
    emit(const UsersLoading());

    final stopwatch = Stopwatch()..start();
    final result = await _getUsers();
    stopwatch.stop();

    result.when(
      success: (users) => emit(UsersLoaded(users, duration: stopwatch.elapsed)),
      failure: (error) => emit(UsersError(error.message)),
    );
  }

  Future<void> _onRefreshUsers(
    RefreshUsers event,
    Emitter<UsersState> emit,
  ) async {
    // Don't show loading state on refresh
    final stopwatch = Stopwatch()..start();
    final result = await _getUsers();
    stopwatch.stop();

    result.when(
      success: (users) => emit(UsersLoaded(users, duration: stopwatch.elapsed)),
      failure: (error) => emit(UsersError(error.message)),
    );
  }
}
