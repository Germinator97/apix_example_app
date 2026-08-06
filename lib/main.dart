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
    // Same values as `SentrySetupOptions.development(...)`, spelled out because
    // the convenience factories don't forward `configureOptions` (apix 2.2.0).
    options: SentrySetupOptions(
      dsn: 'YOUR_DSN_HERE',
      environment: 'development',
      tracesSampleRate: 0.0,
      profilesSampleRate: 0.0,
      replayOnErrorSampleRate: 0.0,
      replaySessionSampleRate: 0.0,
      // v2.2: escape hatch for `SentryFlutterOptions` apix doesn't surface.
      // Runs LAST, after every apix default, so it can override anything —
      // including `beforeSend`. To *compose* with apix's network-noise filter
      // rather than replace it, use `customBeforeSend` instead.
      configureOptions: (sentryOptions) {
        // apix exposes no knob for the breadcrumb ring buffer; this demo keeps
        // a longer trail so the request breadcrumbs emitted by
        // `ErrorTrackingConfig.onBreadcrumb` survive a long tapping session.
        sentryOptions.maxBreadcrumbs = 200;
      },
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
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
