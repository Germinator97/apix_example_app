import 'package:apix_example_app/core/services/v4_demo_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// A demo that quietly stops demonstrating its feature is worse than no demo:
/// it shows a plausible line and nobody looks twice. These tests pin what each
/// probe actually observes, so the screen cannot claim something the library
/// no longer does.
void main() {
  late V4DemoClient client;

  setUp(() => client = V4DemoClient());

  group('V4DemoClient', () {
    test('every probe reports rather than throwing', () async {
      for (final probe in V4Probe.values) {
        final result = await client.run(probe);

        expect(result.probe, equals(probe));
        expect(result.headline, isNotEmpty);
        expect(result.detail, isNotEmpty);
      }
    });

    test('the error-code probe reads the code, not the status', () async {
      final result = await client.run(V4Probe.applicationErrorCode);

      expect(result.headline, contains('OUT_OF_STOCK'));
      expect(
        result.headline,
        contains('Proposer une alternative'),
        reason: 'the branch keyed on the code must be the one that fired',
      );
    });

    test('the rate-limit probe surfaces the Retry-After delay', () async {
      final result = await client.run(V4Probe.rateLimited);

      expect(
        result.headline,
        contains('45'),
        reason:
            'the stub sends Retry-After: 45 — a demo that lost it would '
            'still render a perfectly plausible line',
      );
    });

    test(
      'deduplication collapses concurrent calls but not later ones',
      () async {
        final result = await client.run(V4Probe.deduplicationWithoutCache);

        expect(result.headline, contains('3 concurrent GETs → 1 call'));
        expect(
          result.headline,
          contains('1 more when repeated later'),
          reason:
              'a sequential request must still reach the network — this is '
              'deduplication, not caching',
        );
      },
    );

    test('networkOnly writes nothing', () async {
      final result = await client.run(V4Probe.networkOnlyStoresNothing);

      expect(result.headline, equals('Nothing written to the store'));
      expect(
        result.headline,
        isNot(contains('LEAK')),
        reason:
            'the probe renders a LEAK headline if the store is non-empty, '
            'which is what makes this assertion meaningful',
      );
    });
  });
}
