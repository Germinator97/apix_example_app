import '../services/error_tracking_demo_client.dart';
import '../services/retry_policy_demo_client.dart';
import '../services/robustness_demo_client.dart';
import 'auth_upload_probes.dart';
import 'cache_probes.dart';
import 'demo_probe.dart';
import 'error_probes.dart';
import 'observability_probes.dart';
import 'retry_probes.dart';

/// Every demonstration the app can run, grouped by theme.
///
/// The single place a probe is declared. Before this, adding one meant a new
/// enum value, a new switch arm, a new bloc event, a new state, a new label
/// mapping and a new button — six edits, five of them mechanical, and a demo
/// that grew a bloc per release. Now it is one entry in one list.
class ProbeRegistry {
  ProbeRegistry({
    required RetryPolicyDemoClient retry,
    required ErrorTrackingDemoClient tracking,
    required RobustnessDemoClient robustness,
  }) : all = [
         ...cacheProbes(),
         ...authUploadProbes(),
         ...errorProbes(robustness),
         ...retryProbes(retry, robustness),
         ...observabilityProbes(tracking),
       ];

  /// Every probe, in declaration order.
  final List<DemoProbe> all;

  /// The themes that actually have probes, in enum order.
  ///
  /// Derived rather than listed, so a theme left empty never renders an empty
  /// section — and a theme nobody uses shows up as an obvious gap rather than
  /// as a heading with nothing under it.
  List<ProbeTheme> get themes =>
      ProbeTheme.values.where((t) => byTheme(t).isNotEmpty).toList();

  /// The probes filed under [theme].
  List<DemoProbe> byTheme(ProbeTheme theme) =>
      all.where((probe) => probe.theme == theme).toList();

  /// Looks a probe up by its stable id.
  ///
  /// Returns null when unknown, which is what lets a test assert that an id it
  /// expects still exists rather than silently exercising nothing.
  DemoProbe? byId(String id) {
    for (final probe in all) {
      if (probe.id == id) return probe;
    }
    return null;
  }
}
