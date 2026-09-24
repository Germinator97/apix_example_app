import 'package:apix_example_app/core/probes/demo_probe.dart';
import 'package:apix_example_app/core/probes/probe_registry.dart';
import 'package:apix_example_app/core/services/error_tracking_demo_client.dart';
import 'package:apix_example_app/core/services/retry_policy_demo_client.dart';
import 'package:apix_example_app/core/services/robustness_demo_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards on the registry itself, and on what every probe reports.
///
/// The registry replaced five version-named blocs. Its whole value is that a
/// probe is declared once, so these tests protect the two ways that could rot:
/// a probe declared and unreachable, and a probe that quietly starts reporting
/// a regression while still lighting up green.
void main() {
  late ProbeRegistry registry;

  setUp(() {
    registry = ProbeRegistry(
      retry: RetryPolicyDemoClient(),
      tracking: ErrorTrackingDemoClient(),
      robustness: RobustnessDemoClient(),
    );
  });

  group('registry', () {
    test('every probe has a unique id', () {
      final ids = registry.all.map((p) => p.id).toList();

      expect(
        ids.toSet(),
        hasLength(ids.length),
        reason:
            'ids are what tests key on; a duplicate silently un-tests '
            'one of the two',
      );
    });

    test('every probe carries a label and a theme', () {
      for (final probe in registry.all) {
        expect(probe.label, isNotEmpty, reason: probe.id);
      }
    });

    test('every theme with probes is exposed, and none is empty', () {
      for (final theme in registry.themes) {
        expect(registry.byTheme(theme), isNotEmpty, reason: theme.name);
      }
      // A probe filed under a theme the screen never renders would exist and be
      // unreachable — the exact failure mode the registry exists to prevent.
      final rendered = registry.themes
          .expand(registry.byTheme)
          .map((p) => p.id)
          .toSet();
      expect(rendered, hasLength(registry.all.length));
    });

    test('every theme carries probes', () {
      // Not a count of probes — a count of themes. If a theme empties out, the
      // taxonomy has drifted and that is worth a decision, not a silent gap.
      //
      // `requests` used to be the deliberate exception, its live CRUD and
      // envelope features being hand-written on the screen. It gained a probe
      // the day a download had to show what no button could — the file's
      // bytes with their headers — and this test is where that decision was
      // taken rather than slipped in.
      expect(registry.themes.toSet(), ProbeTheme.values.toSet());
    });

    test('byId finds a known probe and refuses an unknown one', () {
      expect(registry.byId('cache.scoped_to_caller'), isNotNull);
      expect(registry.byId('nope'), isNull);
    });
  });

  group('every probe reports its fix', () {
    /// Runs the probe registered under [id] and returns its headline.
    Future<String> headlineOf(String id) async {
      final probe = registry.byId(id);
      expect(probe, isNotNull, reason: 'no probe registered as "$id"');
      final outcome = await probe!.run();
      expect(outcome.detail, isNotEmpty, reason: id);
      return outcome.headline;
    }

    test('cache — scoped to the caller', () async {
      final headline = await headlineOf('cache.scoped_to_caller');
      expect(headline, isNot(contains('LEAK')));
      expect(headline, contains('token-A'));
      expect(headline, contains('token-B'));
      expect(headline, contains('2 calls'));
    });

    test('cache — an inline query does not collide', () async {
      final headline = await headlineOf('cache.inline_query');
      expect(headline, isNot(contains('COLLISION')));
      expect(headline, contains('2 calls'));
    });

    test('cache — networkOnly writes nothing', () async {
      final headline = await headlineOf('cache.network_only_writes_nothing');
      expect(headline, isNot(contains('LEAK')));
    });

    test('cache — dedup without a cache', () async {
      final headline = await headlineOf('cache.dedup_without_cache');
      expect(headline, contains('3 concurrent GETs → 1 call'));
    });

    test('auth — an upload survives a refresh', () async {
      final headline = await headlineOf('auth.upload_survives_refresh');
      expect(headline, isNot(contains('REGRESSION')));
      expect(headline, contains('HTTP 200'));
      expect(headline, contains('1 file'));
    });

    test('auth — nested multipart keeps everything', () async {
      final headline = await headlineOf('auth.nested_multipart');
      expect(headline, isNot(contains('LOSS')));
      expect(headline, contains('user[avatar]'));
      expect(headline, contains('user[name]=John'));
    });

    test('auth — a broken keychain is its own type', () async {
      final headline = await headlineOf('auth.token_provider_failure');
      expect(headline, contains('TokenProviderException'));
      expect(headline, isNot(contains('REGRESSION')));
    });

    test('errors — an application code drives the reaction', () async {
      final headline = await headlineOf('errors.application_code');
      expect(headline, contains('OUT_OF_STOCK'));
    });

    test('errors — a status is not a code', () async {
      final headline = await headlineOf('errors.status_is_not_a_code');
      expect(headline, isNot(contains('REGRESSION')));
      expect(headline, contains('code=null'));
    });

    test('errors — a rate limit carries its delay', () async {
      final headline = await headlineOf('errors.rate_limited');
      expect(headline, contains('45'));
    });

    test('errors — a business failure in 200 is a failure', () async {
      final headline = await headlineOf('errors.business_failure_in_200');
      expect(headline, isNot(contains('REGRESSION')));
      expect(headline, contains('success=false'));
    });

    test('requests — a download keeps its bytes and headers', () async {
      final headline = await headlineOf('requests.binary_download');
      expect(headline, isNot(contains('REGRESSION')));
      expect(headline, contains('résumé-2026-08.pdf'));
      expect(headline, contains('bytes intact'));
      expect(headline, contains('x-page-count=12'));
    });

    test('errors — a download\'s JSON error keeps its code', () async {
      final headline = await headlineOf('errors.json_error_on_download');
      expect(headline, isNot(contains('REGRESSION')));
      expect(headline, contains('code=EXPORT_TOO_LARGE'));
    });

    test('errors — a bare [] is an empty list', () async {
      final headline = await headlineOf('errors.bare_array');
      expect(headline, isNot(contains('REGRESSION')));
      expect(headline, contains('0 rows'));
    });

    test('observability — a broken sink is harmless', () async {
      final headline = await headlineOf(
        'observability.broken_sink_is_harmless',
      );
      expect(headline, isNot(contains('REGRESSION')));
      expect(headline, contains('HTTP 200'));
    });

    // The four below report a *number* or a *string*, not a marker word, so
    // the registry-wide sweep at the bottom of this file cannot see them fail.
    // A probe whose evidence is "2 network calls" would sail through it.

    test('cache — a broken store still sends one request', () async {
      final headline = await headlineOf('cache.write_failure_sends_once');
      expect(
        headline,
        contains('1 network call'),
        reason:
            'a storage failure used to escape into the network fallback '
            'and re-send the request, handing back the second answer',
      );
      expect(headline, contains('n=1'));
    });

    test('cache — listing the keys keeps the offline fallback', () async {
      final headline = await headlineOf('cache.listing_is_not_deleting');
      expect(headline, contains('served 4200'));
      expect(headline, contains('stale: true'));
    });

    test('cache — a hit and a storage failure are both reported', () async {
      final headline = await headlineOf('cache.hits_are_reportable');
      expect(headline, contains('1 hit reported'));
      expect(headline, contains('1 storage failure reported'));
    });

    test('observability — a retry strands no metric', () async {
      final headline = await headlineOf(
        'observability.retry_leaves_nothing_in_flight',
      );
      expect(headline, contains('3 attempts'));
      expect(headline, contains('1 metric'));
      expect(
        headline,
        contains('0 left in flight'),
        reason: 'two entries used to linger until the five-minute sweep',
      );
    });

    test('observability — the error body stays out of the logs', () async {
      final headline = await headlineOf(
        'observability.error_body_stays_out_of_logs',
      );
      expect(headline, contains('body withheld'));
      expect(headline, contains('500'), reason: 'the status must survive');
      expect(headline, isNot(contains('example.com')));
    });

    test('observability — a query token never reaches the tracker', () async {
      final headline = await headlineOf(
        'observability.query_values_never_reach_the_tracker',
      );
      expect(headline, isNot(contains('super-secret-value')));
      expect(headline, contains('[REDACTED]'));
      expect(
        headline,
        contains('token='),
        reason:
            'the parameter names stay, or the report loses most of its '
            'value',
      );
    });

    test('auth — a typed upload reports progress', () async {
      final headline = await headlineOf('auth.typed_upload_progress');
      expect(headline, contains('id=42'));
      expect(headline, isNot(contains('0 progress callback')));
    });

    test('auth — a FormData replay names itself', () async {
      final headline = await headlineOf('auth.formdata_replay_is_named');
      expect(
        headline,
        contains('MultipartReplayException'),
        reason:
            'it used to surface as ApiException: Unknown error, replacing '
            'the 500 that triggered the replay',
      );
    });
  });

  test('no probe reports a regression, whichever one it is', () async {
    // Sweeps the whole registry, including the probes that hit the mocked
    // network stack above. Its job is to catch a probe added later and never
    // given a test of its own.
    for (final probe in registry.all) {
      final outcome = await probe.run();
      expect(outcome.headline, isNot(contains('REGRESSION')), reason: probe.id);
      expect(outcome.headline, isNot(contains('LEAK')), reason: probe.id);
      expect(outcome.headline, isNot(contains('LOSS')), reason: probe.id);
      expect(outcome.headline, isNot(contains('COLLISION')), reason: probe.id);
      expect(
        outcome.headline,
        isNot(contains('Unexpected success')),
        reason: probe.id,
      );
    }
  });
}
