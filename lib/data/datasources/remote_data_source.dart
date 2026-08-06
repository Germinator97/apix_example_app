import 'dart:io';

// `Options` comes from the apix barrel (re-exported since apix 2.3.0), so no
// direct `package:dio` import is needed here.
import 'package:apix/apix.dart';

import '../models/post.dart';
import '../models/user.dart';

/// Remote data source backed by an Apix [ApiClient].
///
/// Demonstrates:
/// - Plain HTTP verbs (GET/POST/PUT/PATCH/DELETE)
/// - Typed parsers ([ApiClient.getAndParse], [ApiClient.getAndDecode])
/// - Per-request cache strategy override
/// - Multipart upload via [MultipartInterceptor] (auto-detected `File`)
/// - Cache invalidation API
class RemoteDataSource {
  RemoteDataSource(this._client, this._cacheInterceptor);

  final ApiClient _client;
  final CacheInterceptor _cacheInterceptor;

  /// Whether the last response came from the cache (used for a UI badge).
  bool _lastFromCache = false;
  bool get lastFromCache => _lastFromCache;

  /// Whether that cached response was past its TTL.
  ///
  /// apix 3.0.0 serves stale data on purpose in two cases — cacheFirst
  /// revalidating behind, and the offline fallback of networkFirst — so the
  /// UI has to be able to say "showing data from earlier".
  bool _lastFromCacheStale = false;
  bool get lastFromCacheStale => _lastFromCacheStale;

  void _recordProvenance(Response<dynamic> response) {
    _lastFromCache = response.isFromCache;
    _lastFromCacheStale = response.isStale;
  }

  // ============================================================
  // GET (collection / single)
  // ============================================================

  Future<List<UserModel>> getUsers() async {
    final response = await _client.get<dynamic>('/users');
    _recordProvenance(response);
    final data = response.data as List<dynamic>;
    return data
        .map((item) => UserModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> getUser(int id) async {
    return await _client.getAndDecode<UserModel>(
      '/users/$id',
      UserModel.fromJson,
    );
  }

  Future<List<PostModel>> getPosts({
    CacheStrategy strategy = CacheStrategy.networkFirst,
    bool forceRefresh = false,
  }) async {
    final effective = forceRefresh ? CacheStrategy.networkOnly : strategy;
    final response = await _client.get<dynamic>(
      '/posts',
      options: Options(extra: {'cacheStrategy': effective}),
    );
    _recordProvenance(response);
    final data = response.data as List<dynamic>;
    return data
        .map((item) => PostModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ============================================================
  // MUTATIONS — POST / PUT / PATCH / DELETE
  // ============================================================

  Future<PostModel> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    return await _client.postAndDecode<PostModel>('/posts', {
      'title': title,
      'body': body,
      'userId': userId,
    }, PostModel.fromJson);
  }

  Future<PostModel> updatePost({
    required int id,
    required String title,
    required String body,
    required int userId,
  }) async {
    return await _client.putAndDecode<PostModel>('/posts/$id', {
      'id': id,
      'title': title,
      'body': body,
      'userId': userId,
    }, PostModel.fromJson);
  }

  Future<PostModel> patchPost({required int id, required String title}) async {
    return await _client.patchAndDecode<PostModel>('/posts/$id', {
      'title': title,
    }, PostModel.fromJson);
  }

  Future<void> deletePost(int id) async {
    await _client.delete<void>('/posts/$id');
  }

  // ============================================================
  // MULTIPART UPLOAD
  // ============================================================

  /// Uploads a `File` via [MultipartInterceptor].
  ///
  /// JSONPlaceholder echoes the multipart payload back as JSON, which is
  /// enough to demonstrate that the interceptor converted the `File` to a
  /// `MultipartFile` and switched the `Content-Type` to `multipart/form-data`.
  Future<Map<String, dynamic>> uploadFile(
    File file, {
    String label = 'demo',
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/posts',
      data: {'label': label, 'file': file},
    );
    return response.data ?? const {};
  }

  // ============================================================
  // CACHE INVALIDATION
  // ============================================================

  Future<int> clearCache() => _cacheInterceptor.clearCache();

  Future<bool> invalidateUrl(String url) =>
      _cacheInterceptor.invalidateUrl(url);

  Future<int> invalidatePath(String path) =>
      _cacheInterceptor.invalidatePath(path);

  Future<int> invalidateByPrefix(String prefix) =>
      _cacheInterceptor.invalidateByPrefix(prefix);

  Future<List<String>> getCacheKeys() => _cacheInterceptor.getCacheKeys();
}
