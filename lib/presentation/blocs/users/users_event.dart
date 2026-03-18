import 'package:equatable/equatable.dart';

abstract class UsersEvent extends Equatable {
  const UsersEvent();

  @override
  List<Object?> get props => [];
}

class FetchUsers extends UsersEvent {
  const FetchUsers();
}

class RefreshUsers extends UsersEvent {
  const RefreshUsers();
}
