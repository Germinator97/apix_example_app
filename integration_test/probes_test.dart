import 'package:apix_example_app/core/di/injection_container.dart' as di;
import 'package:apix_example_app/core/probes/probe_registry.dart';
import 'package:apix_example_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs **every** probe in the registry on a real device.
///
/// The unit tests already assert what each probe reports. This proves what
/// they cannot: that dependency injection, the registry, the single
/// `ProbeBloc`, the generated buttons and the status bar carry those results to
/// the screen on an actual Android runtime.
///
/// It iterates the registry rather than a hand-written list of labels, so a
/// probe added later is covered here the day it is declared — and rewording a
/// button cannot quietly drop it from the run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Markers a probe uses to say it observed the *old*, broken behaviour.
  const regressionMarkers = [
    'REGRESSION',
    'LEAK',
    'LOSS',
    'COLLISION',
    'Unexpected success',
  ];

  testWidgets('every probe reports its fix on device', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    final registry = di.sl<ProbeRegistry>();
    expect(
      registry.all,
      isNotEmpty,
      reason: 'an empty registry would make this test vacuous',
    );

    var run = 0;
    for (final probe in registry.all) {
      final button = find.widgetWithText(FilledButton, probe.label);

      // The home screen is a lazy `ListView`, so a button below the fold is
      // not merely off-screen — it is absent from the element tree, and `find`
      // reports zero matches rather than "not visible". Scrolling builds it.
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
        reason: 'probe "${probe.id}" is declared but has no button',
      );

      await tester.tap(button);
      // Generous: the retry probes wait out a real Retry-After delay.
      await tester.pumpAndSettle(const Duration(seconds: 4));

      final status = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere(
            (text) =>
                text.contains('${probe.theme.icon} ${probe.label} —') ||
                text.startsWith('❌'),
            orElse: () => '',
          );

      expect(
        status,
        isNotEmpty,
        reason: 'the status bar must report what "${probe.id}" observed',
      );
      for (final marker in regressionMarkers) {
        expect(status, isNot(contains(marker)), reason: probe.id);
      }

      // ignore: avoid_print
      print(
        'PROBE | ${probe.theme.name.padRight(13)} | ${probe.id} -> $status',
      );
      run++;
    }

    expect(run, registry.all.length);
    // ignore: avoid_print
    print('PROBE | $run probes exercised on device');
  });

  tearDownAll(() async {
    await di.sl.reset();
  });
}
