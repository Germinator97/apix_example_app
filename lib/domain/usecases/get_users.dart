import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/user_repository.dart';

/// Use case for fetching users.
class GetUsers {
  final UserRepository _repository;

  GetUsers(this._repository);

  Future<Result<List<User>, Failure>> call() {
    return _repository.getUsers();
  }
}
