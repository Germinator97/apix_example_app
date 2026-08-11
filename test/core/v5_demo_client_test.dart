import 'package:apix_example_app/core/services/v5_demo_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Each probe must report the *fixed* behaviour, not merely run.
///
/// The headlines they produce are what the screen shows, so asserting on them
/// keeps the demo honest: a probe that silently started reporting a regression
/// would still light up green here without these.
void main() {
  late V5DemoClient client;

  setUp(() => client = V5DemoClient());

  test('cache scoping — the second account gets its own body', () async {
    final result = await client.run(V5Probe.cacheIsScopedToCaller);

    expect(result.headline, isNot(contains('LEAK')));
    expect(result.headline, contains('token-A'));
    expect(result.headline, contains('token-B'));
    expect(result.headline, contains('2 calls'));
  });

  test('inline query — two pages, two calls', () async {
    final result = await client.run(V5Probe.inlineQueryDoesNotCollide);

    expect(result.headline, isNot(contains('COLLISION')));
    expect(result.headline, contains('2 calls'));
  });

  test('nested multipart — the sibling and the nesting both survive', () async {
    final result = await client.run(V5Probe.nestedMultipartKeepsEverything);

    expect(result.headline, isNot(contains('LOSS')));
    expect(
      result.headline,
      contains('user[avatar]'),
      reason: 'the outer key must not be flattened away',
    );
    expect(
      result.headline,
      contains('user[name]=John'),
      reason: 'the non-file sibling must still be sent',
    );
  });

  test('upload replay — the rebuilt body still carries the file', () async {
    final result = await client.run(V5Probe.uploadSurvivesTokenRefresh);

    expect(result.headline, isNot(contains('REGRESSION')));
    expect(result.headline, contains('HTTP 200'));
    expect(result.headline, contains('1 file'));
    expect(result.headline, contains('1 field'));
  });

  test('business failure — measured as a failure', () async {
    final result = await client.run(V5Probe.businessFailureIsNotASuccess);

    expect(result.headline, isNot(contains('REGRESSION')));
    expect(result.headline, contains('success=false'));
    expect(result.detail, contains('refused=true'));
  });

  test('bare array — an empty list, not a crash', () async {
    final result = await client.run(V5Probe.bareArrayIsAnEmptyList);

    expect(result.headline, isNot(contains('REGRESSION')));
    expect(result.headline, contains('0 rows'));
  });

  test('every probe is reachable from run()', () async {
    // A probe added to the enum and forgotten in the switch would throw here
    // rather than being noticed the day someone taps its button.
    for (final probe in V5Probe.values) {
      final result = await client.run(probe);
      expect(result.probe, probe);
      expect(result.headline, isNotEmpty);
      expect(result.detail, isNotEmpty);
    }
  });
}
