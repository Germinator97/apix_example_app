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
  DemoProbe(
    id: 'auth.typed_upload_progress',
    theme: ProbeTheme.authUploads,
    label: 'A typed upload reports progress',
    run: _typedUploadProgress,
  ),
  DemoProbe(
    id: 'auth.formdata_replay_is_named',
    theme: ProbeTheme.authUploads,
    label: 'A FormData replay says why',
    run: _formDataReplayIsNamed,
  ),
  DemoProbe(
    id: 'auth.dead_store_is_not_a_dead_entry',
    theme: ProbeTheme.authUploads,
    label: 'A dead store is not a dead entry',
    run: _deadStoreIsNotADeadEntry,
  ),
];

/// The message a consumer captured on Android API 30, plugin 10.3.1, after
/// clearing app data while the Keystore key outlived the preferences.
const _capturedOnDevice =
    'PlatformException(Exception encountered, Migration failed after algorithm '
    'change (Algorithm changed detected). Enable resetOnError=true or call '
    'deleteAll()., Caused by: javax.crypto.IllegalBlockSizeException: '
    'error:1e00007b:Cipher functions:OPENSSL_internal:WRONG_FINAL_BLOCK_LENGTH)';

/// The trap: a dead store whose message contains the words `Bad padding`.
const _theTrap =
    'Key mismatch after algorithm change (Bad padding, wrong key for cipher '
    'algorithm). Enable migrateOnAlgorithmChange=true to preserve data, or '
    'resetOnError=true to delete.';

/// Two failures, one exception type, opposite reactions.
///
/// `flutter_secure_storage` reports both as a `PlatformException` with the same
/// `code: 'Exception encountered'`, so the only discriminator is a substring of
/// the message — and the message for a dead *store* can itself contain the
/// words a dead *entry* is recognised by. Classifying the second as the first
/// takes a deletion the plugin cannot run: every method goes through a
/// successful `initialize`, deletion included.
Future<ProbeOutcome> _deadStoreIsNotADeadEntry() async {
  final captured = SecureStorageService.classify(Exception(_capturedOnDevice));
  final trap = SecureStorageService.classify(Exception(_theTrap));
  final corrupt = SecureStorageService.classify(
    Exception(
      'javax.crypto.AEADBadTagException: '
      'error:1e000065:Cipher functions:OPENSSL_internal:BAD_DECRYPT',
    ),
  );
  final offline = SecureStorageService.classify(
    Exception('SocketException: Failed host lookup: demo.apix'),
  );

  return ProbeOutcome(
    headline:
        'captured=${captured.name} · trap=${trap.name} · '
        'corrupt=${corrupt.name} · offline=${offline.name}',
    detail:
        'The first two are storeUnusable: apix rethrows, deletes nothing, and '
        'answers no null — there is nothing a deletion could reach. The trap '
        'is the one that matters: it carries "Bad padding" inside its '
        'parentheses, and used to be taken for a corrupted entry. The third is '
        'a real corruption measured on an emulator, still recovered by '
        'dropping the key. The fourth is neither, and never a reason to log '
        'anyone out. On storeUnusable, retry once: when the cause is missing '
        'algorithm markers the plugin repairs them as it fails, so the next '
        'call goes through — a second failure is permanent.',
  );
}

/// Upload through a typed method while watching the bytes go out.
Future<ProbeOutcome> _typedUploadProgress() async {
  final file = await _tempFile('passport.png', 'x' * 4096);
  final adapter = ScriptedAdapter(
    (options) => {
      'data': {'id': 42},
    },
  );
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    httpClientAdapter: adapter,
  );

  final ticks = <int>[];
  final id = await client.postAndDecodeData<int>(
    '/documents',
    {'file': file, 'label': 'passport'},
    (json) => json['id'] as int,
    onSendProgress: (sent, total) => ticks.add(sent),
  );

  return ProbeOutcome(
    headline: 'decoded id=$id, ${ticks.length} progress callback(s)',
    detail:
        'The raw verbs took onSendProgress and the sixty typed ones did not, '
        'so a typed upload with a progress bar was not expressible: the only '
        'way to get one was to drop back to client.post and parse the body by '
        'hand, losing the typing those methods exist for. The twelve GET '
        'variants still take only onReceiveProgress — a GET has nothing to '
        'send, and an option that can never fire is one that looks set.',
  );
}

/// Hand apix a FormData it did not build, then force a replay.
Future<ProbeOutcome> _formDataReplayIsNamed() async {
  var seen = 0;
  final adapter = ScriptedAdapter((options) {
    seen++;
    return seen == 1
        ? const ScriptedResponse({'message': 'boom'}, statusCode: 500)
        : {'ok': true};
  });
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    retryConfig: const RetryConfig(maxAttempts: 2, baseDelayMs: 1, jitter: 0),
    httpClientAdapter: adapter,
  );

  final form = FormData.fromMap({'note': 'built by the caller'});

  Object? caught;
  try {
    await client.put<dynamic>('/documents/1', data: form);
  } catch (e) {
    caught = e;
  }

  return ProbeOutcome(
    headline: caught is MultipartReplayException
        ? 'MultipartReplayException after $seen attempt(s)'
        : 'got ${caught.runtimeType}',
    detail:
        'A FormData is single-use — dio finalizes it into a stream — and both '
        'the auth refresh and the retry replay the original RequestOptions. '
        'When you pass a Map of Files apix rebuilds the body per attempt and '
        'the replay simply works; this is the case where it cannot. It used to '
        'surface as a StateError mapped to "ApiException: Unknown error", '
        'REPLACING the 500 that triggered the replay — so on ServerException '
        'catch stopped matching.',
  );
}

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
