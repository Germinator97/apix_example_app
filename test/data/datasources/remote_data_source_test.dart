import 'dart:convert';
import 'dart:typed_data';

import 'package:apix/apix.dart';
import 'package:apix_example_app/data/datasources/remote_data_source.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lightweight in-memory adapter for the JSONPlaceholder-like surface used
/// by [RemoteDataSource]. Records each call so tests can assert behaviour
/// such as "second call hits the cache and never reaches the adapter".
class _RecordingAdapter implements HttpClientAdapter {
  final HttpClientAdapter _fallback = IOHttpClientAdapter();
  int callsForGetPosts = 0;
  int callsForGetUsers = 0;
  int callsForDeletePost = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final method = options.method;
    final path = options.path;

    if (method == 'GET' && path == '/posts') {
      callsForGetPosts++;
      return _ok([
        {'id': 1, 'userId': 1, 'title': 'a', 'body': 'A'},
        {'id': 2, 'userId': 1, 'title': 'b', 'body': 'B'},
      ]);
    }
    if (method == 'GET' && path == '/users') {
      callsForGetUsers++;
      return _ok([
        {'id': 1, 'name': 'Alice', 'email': 'a@x.dev'},
      ]);
    }
    if (method == 'GET' && path.startsWith('/users/')) {
      final id = int.tryParse(path.substring(7)) ?? 0;
      return _ok({'id': id, 'name': 'User $id', 'email': 'u$id@x.dev'});
    }
    if (method == 'POST' && path == '/posts') {
      final body = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : <String, dynamic>{};
      return _ok({
        'id': 101,
        'userId': body['userId'] ?? 1,
        'title': body['title'] ?? '',
        'body': body['body'] ?? '',
      });
    }
    if (method == 'PUT' && path.startsWith('/posts/')) {
      final id = int.tryParse(path.substring(7)) ?? 0;
      final body = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : <String, dynamic>{};
      return _ok({
        'id': id,
        'userId': body['userId'] ?? 1,
        'title': body['title'] ?? '',
        'body': body['body'] ?? '',
      });
    }
    if (method == 'PATCH' && path.startsWith('/posts/')) {
      final id = int.tryParse(path.substring(7)) ?? 0;
      final body = options.data is Map
          ? Map<String, dynamic>.from(options.data as Map)
          : <String, dynamic>{};
      return _ok({
        'id': id,
        'userId': 1,
        'title': body['title'] ?? '',
        'body': 'unchanged',
      });
    }
    if (method == 'DELETE' && path.startsWith('/posts/')) {
      callsForDeletePost++;
      return _ok({});
    }
    return _ok({'error': 'no route for $method $path'}, status: 404);
  }

  ResponseBody _ok(dynamic body, {int status = 200}) {
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) => _fallback.close(force: force);
}

ApiClient _buildClient(_RecordingAdapter adapter, CacheInterceptor cache) {
  final client = ApiClientFactory.create(
    baseUrl: 'https://api.test',
    httpClientAdapter: adapter,
    interceptors: [cache],
  );
  cache.setDio(client.dio);
  return client;
}

void main() {
  late _RecordingAdapter adapter;
  late CacheConfig cacheConfig;
  late CacheInterceptor cache;
  late ApiClient client;
  late RemoteDataSource ds;

  setUp(() {
    adapter = _RecordingAdapter();
    cacheConfig = CacheConfig(
      strategy: CacheStrategy.networkFirst,
      defaultTtl: const Duration(minutes: 5),
    );
    cache = CacheInterceptor(config: cacheConfig);
    client = _buildClient(adapter, cache);
    ds = RemoteDataSource(client, cache);
  });

  group('GET endpoints', () {
    test('getPosts returns parsed list', () async {
      final posts = await ds.getPosts();
      expect(posts, hasLength(2));
      expect(posts.first.title, 'a');
    });

    test('getUsers returns parsed list', () async {
      final users = await ds.getUsers();
      expect(users, hasLength(1));
      expect(users.first.name, 'Alice');
    });

    test('getUser returns single object', () async {
      final user = await ds.getUser(7);
      expect(user.id, 7);
      expect(user.name, 'User 7');
    });
  });

  group('Mutations', () {
    test('createPost forwards body', () async {
      final post = await ds.createPost(title: 'T', body: 'B', userId: 5);
      expect(post.id, 101);
      expect(post.title, 'T');
    });

    test('updatePost (PUT)', () async {
      final post = await ds.updatePost(
        id: 1,
        title: 'New',
        body: 'Body',
        userId: 1,
      );
      expect(post.id, 1);
      expect(post.title, 'New');
    });

    test('patchPost (PATCH)', () async {
      final post = await ds.patchPost(id: 1, title: 'P');
      expect(post.title, 'P');
    });

    test('deletePost (DELETE)', () async {
      await ds.deletePost(1);
      expect(adapter.callsForDeletePost, 1);
    });
  });

  group('Cache integration', () {
    test('cacheFirst hits adapter once then serves cache', () async {
      await ds.getPosts(strategy: CacheStrategy.cacheFirst);
      expect(adapter.callsForGetPosts, 1);
      expect(ds.lastFromCache, isFalse);

      await ds.getPosts(strategy: CacheStrategy.cacheFirst);
      expect(
        adapter.callsForGetPosts,
        1,
        reason: 'second call should be cached',
      );
      expect(ds.lastFromCache, isTrue);
    });

    test('forceRefresh bypasses cache (overrides strategy)', () async {
      await ds.getPosts(strategy: CacheStrategy.cacheFirst);
      expect(adapter.callsForGetPosts, 1);

      await ds.getPosts(strategy: CacheStrategy.cacheFirst, forceRefresh: true);
      expect(
        adapter.callsForGetPosts,
        2,
        reason: 'forceRefresh must hit network',
      );
      expect(ds.lastFromCache, isFalse);
    });

    test('invalidateUrl resolves relative paths against baseUrl', () async {
      await ds.getPosts(strategy: CacheStrategy.cacheFirst);
      expect(adapter.callsForGetPosts, 1);

      final removed = await ds.invalidateUrl('/posts');
      expect(removed, isTrue);

      await ds.getPosts(strategy: CacheStrategy.cacheFirst);
      expect(adapter.callsForGetPosts, 2);
    });

    test('clearCache wipes everything', () async {
      await ds.getPosts(strategy: CacheStrategy.cacheFirst);
      await ds.getUsers();
      final cleared = await ds.clearCache();
      expect(cleared, greaterThanOrEqualTo(1));

      final keys = await ds.getCacheKeys();
      expect(keys, isEmpty);
    });
  });
}
