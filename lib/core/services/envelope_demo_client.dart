import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:apix/apix.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// In-memory ApiClient that demonstrates apix's envelope-unwrapping methods.
///
/// JSONPlaceholder doesn't wrap responses, so we build a tiny mock adapter
/// that replies with `{ "payload": ... }`. The client is configured with
/// `dataKey: 'payload'` so the `*Data` methods extract from this exact key.
class EnvelopeDemoClient {
  EnvelopeDemoClient() {
    final config = ApiClientConfig(
      baseUrl: 'https://envelope.demo.local',
      dataKey: 'payload',
    );
    _client = ApiClientFactory.fromConfig(
      config,
      loggerConfig: LoggerConfig.minimal(),
      httpClientAdapter: _EnvelopeMockAdapter(),
    );
  }

  late final ApiClient _client;

  ApiClient get client => _client;

  /// `getAndDecodeData` — single object inside `{payload: {...}}`.
  Future<Map<String, dynamic>> fetchEnvelopeUser(int id) {
    return _client.getAndDecodeData<Map<String, dynamic>>(
      '/users/$id',
      (json) => json,
    );
  }

  /// `getListAndDecodeData` — list inside `{payload: [...]}`.
  Future<List<Map<String, dynamic>>> fetchEnvelopeUsers() {
    return _client.getListAndDecodeData<Map<String, dynamic>>(
      '/users',
      (json) => json,
    );
  }

  /// `getListAndParseData` — list of primitives inside `{payload: [...]}`.
  Future<List<String>> fetchRoles() {
    return _client.getListAndParseData<String>('/roles', (item) => '$item');
  }

  /// `postAndDecodeData` — POST with envelope response.
  Future<Map<String, dynamic>> createEnvelopeUser({required String name}) {
    return _client.postAndDecodeData<Map<String, dynamic>>('/users', {
      'name': name,
    }, (json) => json);
  }
}

/// A barebones [HttpClientAdapter] that serves canned envelope responses.
///
/// Only matches the routes used by [EnvelopeDemoClient] — anything else
/// returns 404. Built on top of [IOHttpClientAdapter] so close() works
/// without any platform plumbing.
class _EnvelopeMockAdapter implements HttpClientAdapter {
  final HttpClientAdapter _fallback = IOHttpClientAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final path = options.path;

    if (options.method == 'GET' && path == '/users') {
      return _ok({
        'payload': [
          {'id': 1, 'name': 'Alice', 'email': 'alice@example.com'},
          {'id': 2, 'name': 'Bob', 'email': 'bob@example.com'},
        ],
        'meta': {'total': 2},
      });
    }

    if (options.method == 'GET' && path.startsWith('/users/')) {
      final id = int.tryParse(path.substring('/users/'.length)) ?? 0;
      return _ok({
        'payload': {'id': id, 'name': 'User $id', 'email': 'user$id@x.dev'},
        'meta': {'fetched_at': DateTime.now().toIso8601String()},
      });
    }

    if (options.method == 'GET' && path == '/roles') {
      return _ok({
        'payload': ['admin', 'editor', 'viewer'],
      });
    }

    if (options.method == 'POST' && path == '/users') {
      final body = options.data is Map<String, dynamic>
          ? options.data as Map<String, dynamic>
          : <String, dynamic>{};
      return _ok({
        'payload': {
          'id': 42,
          'name': body['name'] ?? 'unnamed',
          'created_at': DateTime.now().toIso8601String(),
        },
      });
    }

    return _notFound(path);
  }

  ResponseBody _ok(Map<String, dynamic> body) {
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  ResponseBody _notFound(String path) {
    final bytes = utf8.encode(jsonEncode({'error': 'no route for $path'}));
    return ResponseBody.fromBytes(
      bytes,
      404,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) => _fallback.close(force: force);
}
