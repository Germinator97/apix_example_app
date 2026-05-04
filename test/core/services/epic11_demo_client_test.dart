import 'package:apix/apix.dart';
import 'package:apix_example_app/core/services/epic11_demo_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end coverage of the four robustness features delivered with
/// apix v2.1.0 plus the [TokenProviderException] path. Each test asserts
/// that the typed exception bubbles up exactly as documented.
void main() {
  late Epic11DemoClient client;

  setUp(() => client = Epic11DemoClient());

  test(
    'triggerParsingFailure → ParsingException with non-null cause',
    () async {
      Object? caught;
      try {
        await client.triggerParsingFailure();
      } on ParsingException catch (e) {
        caught = e;
      }

      expect(caught, isA<ParsingException>());
      final ex = caught! as ParsingException;
      expect(ex.originalError, isNotNull);
    },
  );

  test('triggerCaptivePortal → UnexpectedContentTypeException', () async {
    UnexpectedContentTypeException? caught;
    try {
      await client.triggerCaptivePortal();
    } on UnexpectedContentTypeException catch (e) {
      caught = e;
    }

    expect(caught, isNotNull);
    expect(caught!.expectedContentType, 'application/json');
    expect(caught.actualContentType, contains('text/html'));
  });

  test(
    'triggerBusinessError → BusinessException via responseValidator',
    () async {
      BusinessException? caught;
      try {
        await client.triggerBusinessError();
      } on BusinessException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.code, 'OUT_OF_STOCK');
      expect(caught.message, contains('Article indisponible'));
    },
  );

  test('triggerRetryAfter waits at least the header value (~1s)', () async {
    final elapsed = await client.triggerRetryAfter();
    // Header says 1s; allow some slack for test scheduling.
    expect(
      elapsed,
      greaterThanOrEqualTo(900),
      reason: 'Retry-After: 1 should produce ≥ ~1s wait, got ${elapsed}ms',
    );
    // And not be capped to maxDelayMs (5s) — sanity upper bound.
    expect(elapsed, lessThan(4000));
  });

  test(
    'triggerTokenProviderFailure → TokenProviderException(operation: read)',
    () async {
      TokenProviderException? caught;
      try {
        await client.triggerTokenProviderFailure();
      } on TokenProviderException catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(caught!.operation, TokenProviderOperation.read);
      expect(caught.originalError, isA<StateError>());
    },
  );
}
