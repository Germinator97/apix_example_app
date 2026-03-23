import 'package:apix/apix.dart';
import 'package:dio/dio.dart';

import '../models/post.dart';
import '../models/user.dart';

/// Remote data source using Apix ApiClient.
///
/// All API calls go through [ApiClient] which handles:
/// - Authentication (token injection, refresh)
/// - Retry with exponential backoff
/// - Caching (configurable per request)
/// - Error transformation (DioException → ApiException)
class RemoteDataSource {
  final ApiClient _client;
  final CacheInterceptor? _cacheInterceptor;

  RemoteDataSource(this._client, [this._cacheInterceptor]);

  /// Fetches all users.
  Future<List<UserModel>> getUsers() async {
    return await _client.getListAndDecode<UserModel>(
      '/users',
      (json) => UserModel.fromJson(json['data']),
    );
  }

  /// Fetches a single user by ID.
  Future<UserModel> getUser(int id) async {
    return await _client.getAndDecode<UserModel>(
      '/users/$id',
      (json) => UserModel.fromJson(json['data']),
    );
  }

  /// Fetches all posts with configurable cache strategy.
  Future<List<PostModel>> getPosts({
    CacheStrategy strategy = CacheStrategy.networkFirst,
    bool forceRefresh = false,
  }) async {
    return await _client.getListAndDecode<PostModel>(
      '/posts',
      (json) => PostModel.fromJson(json['data']),
      options: Options(
        extra: {
          'cacheStrategy': strategy,
          if (forceRefresh) 'forceRefresh': true,
        },
      ),
    );
  }

  /// Creates a new post.
  Future<PostModel> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    return await _client.postAndDecode<PostModel>('/posts', {
      'title': title,
      'body': body,
      'userId': userId,
    }, (json) => PostModel.fromJson(json['data']));
  }

  /// Clears the cache.
  Future<int> clearCache() async {
    return await _cacheInterceptor?.clearCache() ?? 0;
  }
}
