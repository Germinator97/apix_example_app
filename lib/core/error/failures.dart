import 'package:apix/apix.dart';

/// Base sealed class for all application Failures.
/// Extends ApiException for compatibility with apix Result type.
sealed class Failure extends ApiException {
  const Failure({required super.message});
}

/// Service temporarily unavailable (timeout, 503, etc.)
class UnavailableFailure extends Failure {
  const UnavailableFailure()
    : super(message: 'Service temporarily unavailable. Please try again.');
}

/// Session expired - user needs to re-authenticate
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure()
    : super(message: 'Session expired. Please log in again.');
}

/// Network connectivity issue
class NetworkFailure extends Failure {
  const NetworkFailure()
    : super(message: 'Network error. Check your internet connection.');
}

/// Unknown/unexpected error with optional custom message
class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'An unexpected error occurred.'});
}
