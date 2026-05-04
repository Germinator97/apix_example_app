import 'package:apix/apix.dart' hide Failure;
import 'package:apix_example_app/core/error/failures.dart';
import 'package:apix_example_app/core/error/wrap_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('wrapExceptions', () {
    test('Success when action completes', () async {
      final result = await wrapExceptions<int>(() async => 42);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 42);
    });

    test('TimeoutException → UnavailableFailure', () async {
      final result = await wrapExceptions<int>(() async {
        throw const TimeoutException(message: 'timed out');
      });

      expect(result.isFailure, isTrue);
      expect(result.errorOrNull, isA<UnavailableFailure>());
    });

    test('ConnectionException → UnavailableFailure', () async {
      final result = await wrapExceptions<int>(() async {
        throw const ConnectionException(message: 'offline');
      });

      expect(result.errorOrNull, isA<UnavailableFailure>());
    });

    test('UnauthorizedException → UnauthorizedFailure', () async {
      final result = await wrapExceptions<int>(() async {
        throw const UnauthorizedException();
      });

      expect(result.errorOrNull, isA<UnauthorizedFailure>());
    });

    test('ForbiddenException → ForbiddenFailure', () async {
      final result = await wrapExceptions<int>(() async {
        throw const ForbiddenException();
      });

      expect(result.errorOrNull, isA<ForbiddenFailure>());
    });

    test('NotFoundException → NotFoundFailure', () async {
      final result = await wrapExceptions<int>(() async {
        throw const NotFoundException();
      });

      expect(result.errorOrNull, isA<NotFoundFailure>());
    });

    test('Bare NetworkException → NetworkFailure', () async {
      final result = await wrapExceptions<int>(() async {
        throw const NetworkException(message: 'generic');
      });

      expect(result.errorOrNull, isA<NetworkFailure>());
    });

    test('HttpException 503 → UnavailableFailure', () async {
      final result = await wrapExceptions<int>(() async {
        throw const HttpException(message: 'unavailable', statusCode: 503);
      });

      expect(result.errorOrNull, isA<UnavailableFailure>());
    });

    test('HttpException 500 → UnknownFailure with backend message', () async {
      final result = await wrapExceptions<int>(() async {
        throw const HttpException(message: 'oops', statusCode: 500);
      });

      expect(result.errorOrNull, isA<UnknownFailure>());
      expect(result.errorOrNull!.message, 'oops');
    });

    test(
      'Generic ApiException → UnknownFailure with original message',
      () async {
        final result = await wrapExceptions<int>(() async {
          throw const ApiException(message: 'unmapped');
        });

        expect(result.errorOrNull, isA<UnknownFailure>());
        expect(result.errorOrNull!.message, 'unmapped');
      },
    );

    test('ParsingException → ParsingFailure (apix v2.1)', () async {
      final result = await wrapExceptions<int>(() async {
        throw const ParsingException(message: 'truncated json');
      });

      expect(result.errorOrNull, isA<ParsingFailure>());
    });

    test(
      'UnexpectedContentTypeException → CaptivePortalFailure (apix v2.1)',
      () async {
        final result = await wrapExceptions<int>(() async {
          throw const UnexpectedContentTypeException(
            expectedContentType: 'application/json',
            actualContentType: 'text/html',
            statusCode: 200,
          );
        });

        expect(result.errorOrNull, isA<CaptivePortalFailure>());
      },
    );

    test('TokenProviderException → UnauthorizedFailure (apix v2.1)', () async {
      final result = await wrapExceptions<int>(() async {
        throw const TokenProviderException(
          operation: TokenProviderOperation.read,
          message: 'keychain unavailable',
        );
      });

      expect(result.errorOrNull, isA<UnauthorizedFailure>());
    });
  });
}
