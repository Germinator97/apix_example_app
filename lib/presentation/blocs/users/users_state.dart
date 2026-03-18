import 'package:equatable/equatable.dart';

import '../../../domain/entities/user.dart';

abstract class UsersState extends Equatable {
  const UsersState();

  @override
  List<Object?> get props => [];
}

class UsersInitial extends UsersState {
  const UsersInitial();
}

class UsersLoading extends UsersState {
  const UsersLoading();
}

class UsersLoaded extends UsersState {
  final List<User> users;
  final Duration? duration;

  const UsersLoaded(this.users, {this.duration});

  @override
  List<Object?> get props => [users, duration];
}

class UsersError extends UsersState {
  final String message;

  const UsersError(this.message);

  @override
  List<Object?> get props => [message];
}
