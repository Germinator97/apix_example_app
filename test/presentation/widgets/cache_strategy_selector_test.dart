import 'package:apix/apix.dart';
import 'package:apix_example_app/presentation/widgets/cache_strategy_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({
    required CacheStrategy selected,
    required ValueChanged<CacheStrategy> onChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CacheStrategySelector(selected: selected, onChanged: onChanged),
      ),
    );
  }

  testWidgets('renders one button per CacheStrategy value', (tester) async {
    await tester.pumpWidget(
      host(selected: CacheStrategy.networkFirst, onChanged: (_) {}),
    );

    for (final s in CacheStrategy.values) {
      expect(
        find.text(_label(s)),
        findsOneWidget,
        reason: '${s.name} button missing',
      );
    }
  });

  testWidgets('emits the tapped strategy', (tester) async {
    CacheStrategy? captured;
    await tester.pumpWidget(
      host(
        selected: CacheStrategy.networkFirst,
        onChanged: (s) => captured = s,
      ),
    );

    await tester.tap(find.text('Cache First'));
    await tester.pumpAndSettle();
    expect(captured, CacheStrategy.cacheFirst);

    await tester.tap(find.text('HTTP Cache'));
    await tester.pumpAndSettle();
    expect(captured, CacheStrategy.httpCacheAware);
  });
}

String _label(CacheStrategy s) => switch (s) {
  CacheStrategy.cacheFirst => 'Cache First',
  CacheStrategy.networkFirst => 'Network First',
  CacheStrategy.cacheOnly => 'Cache Only',
  CacheStrategy.networkOnly => 'Network Only',
  CacheStrategy.httpCacheAware => 'HTTP Cache',
};
