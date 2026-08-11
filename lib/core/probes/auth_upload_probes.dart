import 'dart:io';

import 'package:apix/apix.dart';

import 'demo_probe.dart';
import 'scripted_adapter.dart';

/// Credentials and file uploads — the two things that fail together.
///
/// An upload meeting an expired token is the commonest interaction there is,
/// and it was the one apix could not survive: `FormData` is single-use, and
/// both the refresh and the retry replay the original request.
List<DemoProbe> authUploadProbes() => [
  DemoProbe(
    id: 'auth.upload_survives_refresh',
    theme: ProbeTheme.authUploads,
    label: 'Upload survives a token refresh',
    run: _uploadSurvivesRefresh,
  ),
  DemoProbe(
    id: 'auth.nested_multipart',
    theme: ProbeTheme.authUploads,
    label: 'Nested multipart keeps everything',
    run: _nestedMultipart,
  ),
  DemoProbe(
    id: 'auth.token_provider_failure',
    theme: ProbeTheme.authUploads,
    label: 'TokenProviderException',
    run: _tokenProviderFailure,
  ),
];

Future<ProbeOutcome> _uploadSurvivesRefresh() async {
  final file = await _tempFile('report.pdf', 'pdf-bytes');
  var calls = 0;
  final adapter = ScriptedAdapter((options) {
    if (options.path.contains('refresh')) {
      return {'access_token': 'fresh-token'};
    }
    calls++;
    // First attempt: the token is stale. The replay must carry a body of its
    // own, or it never gets this far.
    if (calls == 1) throw const Unauthorized();
    return {'uploaded': true};
  });

  final tokens = MutableTokenProvider('stale-token');
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    authConfig: AuthConfig(
      tokenProvider: tokens,
      refreshEndpoint: '/auth/refresh',
      onTokenRefreshed: (response) async {
        await tokens.saveTokens('fresh-token', 'fresh-refresh');
      },
    ),
    httpClientAdapter: adapter,
  );

  try {
    final response = await client.post<dynamic>(
      '/upload',
      data: {'file': file, 'caption': 'holiday'},
    );
    final replayed = adapter.lastRequest!.data as FormData;
    return ProbeOutcome(
      headline:
          'HTTP ${response.statusCode} after refresh — replay carried '
          '${replayed.files.length} file, ${replayed.fields.length} field',
      detail:
          'A FormData is single-use, and both the refresh and the retry replay '
          'the original RequestOptions — so an upload with an expired token '
          'failed outright. The refresh queue, the headline feature, was '
          'inoperative for uploads. apix now rebuilds the body per attempt.',
    );
  } on ApiException catch (e) {
    return ProbeOutcome(
      headline: 'REGRESSION — the replayed upload failed',
      detail: '${e.runtimeType}: ${e.message}',
    );
  }
}

Future<ProbeOutcome> _nestedMultipart() async {
  final file = await _tempFile('avatar.png', 'not-really-an-image');
  final adapter = ScriptedAdapter((options) => {'ok': true});
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    httpClientAdapter: adapter,
  );

  await client.post<dynamic>(
    '/profile',
    data: {
      'user': {'avatar': file, 'name': 'John'},
    },
  );

  final sent = adapter.lastRequest!.data as FormData;
  final fields = sent.fields.map((e) => '${e.key}=${e.value}').join(', ');
  final files = sent.files.map((e) => e.key).join(', ');
  final complete = sent.files.length == 1 && sent.fields.length == 1;

  return ProbeOutcome(
    headline: complete
        ? 'Sent files[$files] fields[$fields]'
        : 'LOSS — files[$files] fields[$fields]',
    detail:
        'File detection was recursive, the conversion one level deep, so '
        'everything below that level was dropped without a word while the '
        'server answered 200. A file two levels down sent an EMPTY body.',
  );
}

/// A keychain that will not open must surface as its own type.
Future<ProbeOutcome> _tokenProviderFailure() async {
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    authConfig: const AuthConfig(tokenProvider: FaultyTokenProvider()),
    httpClientAdapter: ScriptedAdapter((options) => {'ok': true}),
  );

  try {
    await client.get<dynamic>('/profile');
    return const ProbeOutcome(
      headline: 'Unexpected success',
      detail: 'the provider always throws',
    );
  } on TokenProviderException catch (e) {
    return ProbeOutcome(
      headline: 'Caught TokenProviderException (${e.operation.name})',
      detail:
          'Storage failures are told apart from network and HTTP ones, so a '
          'corrupted keychain can prompt a fresh login instead of looking like '
          'an outage. ${e.message}',
    );
  } on ApiException catch (e) {
    return ProbeOutcome(
      headline: 'REGRESSION — got ${e.runtimeType}',
      detail: e.message,
    );
  }
}

/// Writes a real file: the multipart probes are about what happens to a
/// `File`, and a stub would prove nothing.
Future<File> _tempFile(String name, String contents) async {
  final dir = await Directory.systemTemp.createTemp('apix_demo');
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsString(contents);
  return file;
}
