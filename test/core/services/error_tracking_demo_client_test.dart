import 'package:apix_example_app/core/services/error_tracking_demo_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards what apix hands to an error tracker — the 3.0.0 change.
///
/// Runs through a real `ApiClient` with a mocked transport, so the failures
/// travel the actual interceptor chain rather than a stub of it.
void main() {
  late ErrorTrackingDemoClient client;

  setUp(() => client = ErrorTrackingDemoClient());

  test('a 500 is reported to the tracker as ServerException', () async {
    final result = await client.run(TrackingProbe.serverError);

    expect(result.caught, 'ServerException');
    expect(
      result.reported,
      'ServerException',
      reason:
          'the tracker must receive the same typed exception the caller '
          'catches — trackers group issues by runtime type',
    );
    expect(result.filteredAsNoise, isFalse);
    expect(
      result.reportedRawDioError,
      isFalse,
      reason:
          'before 3.0.0 this was DioException, which filed every 500, 404 and '
          'timeout under a single issue',
    );
  });

  test('a dropped connection is reported, then filtered as noise', () async {
    final result = await client.run(TrackingProbe.connectionLost);

    expect(result.caught, 'ConnectionException');
    // Two stages, and it matters which one acts: the interceptor captures
    // every non-HTTP failure, so this DOES reach `onError`...
    expect(
      result.reported,
      'ConnectionException',
      reason:
          'the interceptor captures non-badResponse failures unconditionally',
    );
    // ...and the noise filter is what keeps it out of the dashboard.
    expect(result.filteredAsNoise, isTrue);
    expect(
      result.reachesDashboard,
      isFalse,
      reason: 'a user losing signal is not an incident',
    );
  });

  test('the two probes differ in what they send', () async {
    // The contrast is the point. If both ever reported — or both stayed
    // silent — the demo would be showing nothing while still looking green.
    final server = await client.run(TrackingProbe.serverError);
    final offline = await client.run(TrackingProbe.connectionLost);

    expect(server.reachesDashboard, isTrue);
    expect(offline.reachesDashboard, isFalse);
    expect(server.caught, isNot(offline.caught));
  });
}
