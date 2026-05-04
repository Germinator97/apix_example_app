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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ApixColors.deepNavy.withValues(alpha: 0.05),
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
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: ApixColors.slateGray,
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
                color: metrics.success
                    ? ApixColors.borderBlue
                    : Colors.red.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
