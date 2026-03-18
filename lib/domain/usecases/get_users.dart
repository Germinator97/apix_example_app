import 'package:apix/apix.dart';

import '../entities/user.dart';
import '../repositories/user_repository.dart';

/// Use case for fetching users.
class GetUsers {
  final UserRepository _repository;

  GetUsers(this._repository);

  Future<Result<List<User>, ApiException>> call() {
    return _repository.getUsers();
  }
}
