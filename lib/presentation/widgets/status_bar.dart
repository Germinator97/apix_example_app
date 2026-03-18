import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class StatusBar extends StatelessWidget {
  final String message;

  const StatusBar({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
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
      child: Text(
        message,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: ApixColors.slateGray,
        ),
      ),
    );
  }
}
