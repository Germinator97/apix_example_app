import 'package:apix/apix.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CacheStrategySelector extends StatelessWidget {
  final CacheStrategy selected;
  final ValueChanged<CacheStrategy> onChanged;

  const CacheStrategySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CacheStrategy.values.map((strategy) {
        final isSelected = strategy == selected;
        final scheme = Theme.of(context).colorScheme;
        return FilledButton(
          onPressed: () => onChanged(strategy),
          style: FilledButton.styleFrom(
            // Unselected chips take their colours from the scheme rather than
            // a fixed navy-on-translucent-navy pair: that pair was legible on
            // the light background it was designed for and unreadable on the
            // dark one, where both ends collapsed towards black.
            backgroundColor: isSelected
                ? ApixColors.sparkOrange
                : scheme.surfaceContainerHighest,
            foregroundColor: isSelected
                ? ApixColors.onSparkOrange
                : scheme.onSurfaceVariant,
          ),
          child: Text(_getLabel(strategy)),
        );
      }).toList(),
    );
  }

  String _getLabel(CacheStrategy strategy) {
    return switch (strategy) {
      CacheStrategy.cacheFirst => 'Cache First',
      CacheStrategy.networkFirst => 'Network First',
      CacheStrategy.cacheOnly => 'Cache Only',
      CacheStrategy.networkOnly => 'Network Only',
      CacheStrategy.httpCacheAware => 'HTTP Cache',
    };
  }
}
