import 'dart:convert';
import 'dart:typed_data';

import 'package:apix/apix.dart';
import 'package:apix/testing.dart';

/// Signals "answer 401" from inside a [ScriptedAdapter] callback.
class Unauthorized implements Exception {
  const Unauthorized();
}

/// An [HttpClientAdapter] that answers from a callback and records what it saw.
///
/// One adapter for every probe. Each demo client used to carry its own private
/// near-copy — five of them, differing only in what they counted — which is how
/// a probe ended up unable to assert on the request it had just sent without
/// first extending its own adapter.
///
/// Note the `Stream<List<int>>?` parameter: dio declares `Stream<Uint8List>?`,
/// and a supertype is legal in an override. It keeps this compiling across the
/// whole dio range apix supports.
class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.respond);

  /// Builds the body for a request. Throw [Unauthorized] to answer `401`, or
  /// return a [ScriptedResponse] to control the status and headers. A
  /// `Uint8List` body is sent as raw bytes; anything else as JSON.
  final Object? Function(RequestOptions options) respond;

  /// How many requests reached the adapter.
  int hits = 0;

  /// Every request seen, in order.
  final List<RequestOptions> seen = [];

  /// The most recent request — what a probe inspects to prove what was sent.
  RequestOptions? get lastRequest => seen.isEmpty ? null : seen.last;

  /// Total bytes read off the request stream, across every request.
  int sentBytes = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    hits++;
    seen.add(options);

    // Drain the body, as any real adapter does when it writes it to a socket.
    //
    // Not cosmetic: dio drives `onSendProgress` from the stream being *read*,
    // so an adapter that ignores it reports zero progress on an upload that is
    // wired correctly — a stub disproving a feature it simply never exercised.
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        sentBytes += chunk.length;
      }
    }
    try {
      final answer = respond(options);
      if (answer is ScriptedResponse) {
        return _body(answer.body, answer.statusCode, answer.headers);
      }
      return _body(answer, 200, const {});
    } on Unauthorized {
      return _body({'message': 'Token expiré.'}, 401, const {});
    }
  }

  ResponseBody _body(
    Object? body,
    int statusCode,
    Map<String, List<String>> headers,
  ) {
    // Raw bytes — a file — go out untouched, under the headers the script
    // names: JSON-encoding them would turn a PDF into a list of numbers.
    if (body is Uint8List) {
      return ResponseBody.fromBytes(body, statusCode, headers: headers);
    }
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode(body)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: const ['application/json'],
        ...headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A scripted answer with a status and headers of its own.
class ScriptedResponse {
  const ScriptedResponse(
    this.body, {
    this.statusCode = 200,
    this.headers = const {},
  });

  final Object? body;
  final int statusCode;
  final Map<String, List<String>> headers;
}

/// A [TokenProvider] whose token can change mid-run, which is what a logout
/// followed by a login looks like from the client's side.
class MutableTokenProvider implements TokenProvider {
  MutableTokenProvider(this.accessToken, {this.refreshToken = 'refresh-token'});

  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens(String access, String refresh) async {
    accessToken = access;
    refreshToken = refresh;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

/// A [TokenProvider] whose reads always fail, standing in for a corrupted
/// keychain or a missing entitlement.
class FaultyTokenProvider implements TokenProvider {
  const FaultyTokenProvider();

  @override
  Future<String?> getAccessToken() async {
    throw Exception('Keychain unavailable (simulated)');
  }

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<void> saveTokens(String accessToken, String refreshToken) async {}

  @override
  Future<void> clearTokens() async {}
}
