import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../../core/error/wrap_exceptions.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/remote_data_source.dart';

/// Implementation of UserRepository using RemoteDataSource.
///
/// Uses [wrapExceptions] to convert ApiException to user-friendly Failure.
class UserRepositoryImpl implements UserRepository {
  final RemoteDataSource _remoteDataSource;

  UserRepositoryImpl(this._remoteDataSource);

  @override
  Future<Result<List<User>, Failure>> getUsers() {
    return wrapExceptions(() async {
      final data = await _remoteDataSource.getUsers();
      return data.map((e) => e.toEntity()).toList();
    });
  }

  @override
  Future<Result<User, Failure>> getUser(int id) {
    return wrapExceptions(() async {
      final data = await _remoteDataSource.getUser(id);
      return data.toEntity();
    });
  }
}
