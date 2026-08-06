import 'package:apix/apix.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';

/// Sentry DSN, supplied at build time — never committed.
///
/// ```bash
/// flutter run --dart-define=SENTRY_DSN=https://…@…ingest.sentry.io/…
/// ```
///
/// Empty by default, which disables Sentry entirely (see `enabled` below) so
/// the app runs without one.
const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

void main() async {
  // Initialize Sentry
  SentryWidgetsFlutterBinding.ensureInitialized();

  // Initialize dependencies
  await initDependencies();

  await SentrySetup.init(
    // Same values as `SentrySetupOptions.development(...)`, spelled out because
    // the convenience factories don't forward `configureOptions` (apix 2.2.0).
    options: SentrySetupOptions(
      dsn: sentryDsn,
      // Without a DSN, skip Sentry rather than initialising it with an empty
      // one: `SentrySetup.init` then just runs the app.
      enabled: sentryDsn.isNotEmpty,
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
      // Light only. This demo is read as much as it is used — status messages,
      // cache badges, probe counts — and the Apix palette was built against a
      // light surface. There is no dark theme to fall back to, so no
      // `themeMode` to pin.
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
