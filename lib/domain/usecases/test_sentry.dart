import 'package:apix/apix.dart';

import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Use case to test Sentry integration.
/// Triggers various error scenarios to verify Sentry captures them correctly.
class TestSentry {
  final PostRepository _repository;

  TestSentry(this._repository);

  /// Triggers a test error that should be captured by Sentry.
  Future<Result<void, ApiException>> triggerTestError() async {
    try {
      throw ApiException(
        message: 'Test error from ApiX Example App',
        statusCode: 500,
      );
    } on ApiException catch (e) {
      return Failure(e);
    }
  }

  /// Triggers a network timeout simulation.
  Future<Result<void, ApiException>> triggerTimeout() async {
    try {
      throw TimeoutException(
        message: 'Simulated timeout for Sentry test',
        duration: const Duration(seconds: 30),
      );
    } on ApiException catch (e) {
      return Failure(e);
    }
  }

  /// Triggers a 404 Not Found error.
  Future<Result<void, ApiException>> triggerNotFound() async {
    try {
      throw const NotFoundException(
        message: 'Resource not found - Sentry test',
      );
    } on ApiException catch (e) {
      return Failure(e);
    }
  }

  /// Triggers an unauthorized error.
  Future<Result<void, ApiException>> triggerUnauthorized() async {
    try {
      throw UnauthorizedException(message: 'Unauthorized access - Sentry test');
    } on ApiException catch (e) {
      return Failure(e);
    }
  }

  /// Triggers a real API call with cacheOnly (will fail if no cache).
  Future<Result<List<Post>, ApiException>> triggerRealApiError() async {
    return _repository.getPosts(
      strategy: CacheStrategy.cacheOnly,
      forceRefresh: false,
    );
  }
}
