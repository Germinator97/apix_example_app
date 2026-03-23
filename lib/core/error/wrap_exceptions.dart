import 'package:apix/apix.dart' hide Failure;

import 'failures.dart';

/// Wraps async operations and converts ApiException to typed Failure.
///
/// This centralizes error handling and provides user-friendly messages.
///
/// Example:
/// ```dart
/// Future<Result<List<User>, Failure>> getUsers() {
///   return wrapExceptions(() async {
///     final data = await _remote.getUsers();
///     return data.map(User.fromJson).toList();
///   });
/// }
/// ```
Future<Result<T, Failure>> wrapExceptions<T>(
  Future<T> Function() action,
) async {
  try {
    final result = await action();
    return Result.success(result);
  } on (TimeoutException, ConnectionException) {
    return Result.failure(const UnavailableFailure());
  } on UnauthorizedException {
    return Result.failure(const UnauthorizedFailure());
  } on NetworkException {
    return Result.failure(const NetworkFailure());
  } on ServerException catch (e) {
    if (e.statusCode == 503) {
      return Result.failure(const UnavailableFailure());
    }
    return Result.failure(UnknownFailure(message: e.message));
  } on ApiException {
    return Result.failure(const UnknownFailure());
  }
}
