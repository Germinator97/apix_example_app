import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../entities/user.dart';

/// Repository interface for user operations.
abstract class UserRepository {
  /// Fetches all users.
  Future<Result<List<User>, Failure>> getUsers();

  /// Fetches a single user by ID.
  Future<Result<User, Failure>> getUser(int id);
}
