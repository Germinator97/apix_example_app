import 'package:apix/apix.dart';

import '../entities/user.dart';

/// Repository interface for user operations.
abstract class UserRepository {
  /// Fetches all users.
  Future<Result<List<User>, ApiException>> getUsers();

  /// Fetches a single user by ID.
  Future<Result<User, ApiException>> getUser(int id);
}
