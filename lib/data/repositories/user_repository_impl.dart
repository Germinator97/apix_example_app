import 'package:apix/apix.dart';

import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/remote_data_source.dart';

/// Implementation of UserRepository using RemoteDataSource.
class UserRepositoryImpl implements UserRepository {
  final RemoteDataSource _remoteDataSource;

  UserRepositoryImpl(this._remoteDataSource);

  @override
  Future<Result<List<User>, ApiException>> getUsers() async {
    try {
      final data = await _remoteDataSource.getUsers();
      final users = data.map(_mapToUser).toList();
      return Success(users);
    } on ApiException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiException(message: e.toString()));
    }
  }

  @override
  Future<Result<User, ApiException>> getUser(int id) async {
    try {
      final data = await _remoteDataSource.getUser(id);
      return Success(_mapToUser(data));
    } on ApiException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiException(message: e.toString()));
    }
  }

  User _mapToUser(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
    );
  }
}
