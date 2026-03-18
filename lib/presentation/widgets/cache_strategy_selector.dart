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
        return FilledButton(
          onPressed: () => onChanged(strategy),
          style: FilledButton.styleFrom(
            backgroundColor: isSelected
                ? ApixColors.sparkOrange
                : ApixColors.deepNavy.withValues(alpha: 0.1),
            foregroundColor: isSelected
                ? ApixColors.white
                : ApixColors.deepNavy,
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
