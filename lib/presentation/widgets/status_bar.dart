import 'package:apix/apix.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class StatusBar extends StatelessWidget {
  final String message;
  final RequestMetrics? lastMetrics;

  const StatusBar({super.key, required this.message, this.lastMetrics});

  @override
  Widget build(BuildContext context) {
    final metrics = lastMetrics;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: ApixColors.borderBlue.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              // From the scheme, not the fixed slateGray: that one is only
              // legible on a light surface.
              color: scheme.onSurface,
            ),
          ),
          if (metrics != null) ...[
            const SizedBox(height: 6),
            Text(
              '↳ ${metrics.method} ${metrics.path} '
              '[${metrics.statusCode ?? '?'}] ${metrics.durationMs ?? '?'}ms'
              '${metrics.success ? '' : ' · ${metrics.errorType ?? 'error'}'}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: metrics.success ? scheme.onSurfaceVariant : scheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
