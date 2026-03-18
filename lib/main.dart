import 'package:apix/apix.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  // Initialize Sentry
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Initialize dependencies
  await initDependencies();

  await SentrySetup.init(
    options: SentrySetupOptions.development(
      dsn: 'YOUR_DSN_HERE',
    ),
    appRunner: () async {
      runApp(const ApixExampleApp());
    },
  );
}

class ApixExampleApp extends StatelessWidget {
  const ApixExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ApiX Example',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
