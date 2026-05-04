import 'package:apix/apix.dart' hide Failure;

import 'failures.dart';

/// Wraps async operations and converts [ApiException] subtypes to a domain
/// [Failure] usable with `Result.when` in BLoCs.
///
/// Note: ApiX's `ErrorMapperInterceptor` only emits `Unauthorized`,
/// `Forbidden`, `NotFound` or generic `HttpException` for HTTP errors —
/// `ServerException` is never thrown, so we route 5xx through `HttpException`.
///
/// Order matters: more-specific subclasses must come before their parents
/// (e.g. `UnauthorizedException` before `HttpException`,
/// `TokenProviderException` before its `ApiException` parent).
///
/// Example:
/// ```dart
/// Future<Result<List<User>, Failure>> getUsers() {
///   return wrapExceptions(() async => _remote.getUsers());
/// }
/// ```
Future<Result<T, Failure>> wrapExceptions<T>(
  Future<T> Function() action,
) async {
  try {
    final result = await action();
    return Result.success(result);
  } on TimeoutException {
    return Result.failure(const UnavailableFailure());
  } on ConnectionException {
    return Result.failure(const UnavailableFailure());
  } on UnauthorizedException {
    return Result.failure(const UnauthorizedFailure());
  } on ForbiddenException {
    return Result.failure(const ForbiddenFailure());
  } on NotFoundException {
    return Result.failure(const NotFoundFailure());
  } on TokenProviderException {
    // Keychain corrupted, custom TokenProvider threw — force re-login.
    return Result.failure(const UnauthorizedFailure());
  } on UnexpectedContentTypeException {
    // Captive Wi-Fi portal returning HTML for a JSON endpoint.
    return Result.failure(const CaptivePortalFailure());
  } on ParsingException {
    return Result.failure(const ParsingFailure());
  } on NetworkException {
    return Result.failure(const NetworkFailure());
  } on HttpException catch (e) {
    if (e.statusCode == 503) {
      return Result.failure(const UnavailableFailure());
    }
    return Result.failure(UnknownFailure(message: e.message));
  } on ApiException catch (e) {
    return Result.failure(UnknownFailure(message: e.message));
  }
}
