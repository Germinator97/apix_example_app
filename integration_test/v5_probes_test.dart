import 'package:apix_example_app/core/di/injection_container.dart' as di;
import 'package:apix_example_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Drives the six v5 probes **on a real device**, through the real widget tree.
///
/// The unit tests already assert what each probe reports. This exists to prove
/// something they cannot: that the whole app — dependency injection, the bloc
/// wiring, the buttons, the status bar — carries those results to the screen on
/// an actual Android runtime rather than in the Dart VM on a laptop.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Taps the button labelled [label] and returns the status bar text it
  /// produced.
  Future<String> runProbe(WidgetTester tester, String label) async {
    final button = find.widgetWithText(FilledButton, label);

    // The home screen is a lazy `ListView`, so a button below the fold is not
    // merely off-screen — it is absent from the element tree, and `find`
    // reports zero matches rather than "not visible". Scrolling to it is what
    // builds it.
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 200,
    );
    await tester.pumpAndSettle();

    expect(
      button,
      findsOneWidget,
      reason: 'the "$label" button must exist on the home screen',
    );

    await tester.tap(button);
    // Long enough for the probe's own awaits (refresh round trip, file write).
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final status = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere(
          (text) => text.startsWith('🔎') || text.startsWith('❌'),
          orElse: () => '',
        );

    expect(
      status,
      isNotEmpty,
      reason: 'the status bar must report what "$label" observed',
    );
    // ignore: avoid_print
    print('PROBE RESULT | $label -> $status');
    return status;
  }

  testWidgets('the six v5 probes report their fix on device', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final cache = await runProbe(tester, 'Cache is scoped to the caller');
    expect(cache, contains('token-A'));
    expect(cache, contains('token-B'));
    expect(cache, isNot(contains('LEAK')));

    final query = await runProbe(tester, 'Inline ?page= does not collide');
    expect(query, contains('2 calls'));
    expect(query, isNot(contains('COLLISION')));

    final multipart = await runProbe(
      tester,
      'Nested multipart keeps everything',
    );
    expect(multipart, contains('user[avatar]'));
    expect(multipart, contains('user[name]=John'));
    expect(multipart, isNot(contains('LOSS')));

    final upload = await runProbe(tester, 'Upload survives a token refresh');
    expect(upload, contains('HTTP 200'));
    expect(upload, contains('1 file'));
    expect(upload, isNot(contains('REGRESSION')));

    final business = await runProbe(tester, '200 + success:false is a failure');
    expect(business, contains('success=false'));
    expect(business, isNot(contains('REGRESSION')));

    final bare = await runProbe(tester, 'A bare [] is an empty list');
    expect(bare, contains('0 rows'));
    expect(bare, isNot(contains('REGRESSION')));
  });

  tearDownAll(() async {
    await di.sl.reset();
  });
}
