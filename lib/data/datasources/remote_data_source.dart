import 'package:apix/apix.dart';
import 'package:dio/dio.dart';

/// Remote data source using Apix ApiClient.
class RemoteDataSource {
  final ApiClient _client;
  final CacheInterceptor _cacheInterceptor;

  RemoteDataSource(this._client, this._cacheInterceptor);

  /// Fetches all users.
  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _client.get<List<dynamic>>('/users');
    return response.data!.cast<Map<String, dynamic>>();
  }

  /// Fetches a single user by ID.
  Future<Map<String, dynamic>> getUser(int id) async {
    final response = await _client.get<Map<String, dynamic>>('/users/$id');
    return response.data!;
  }

  /// Fetches all posts with configurable cache strategy.
  Future<List<Map<String, dynamic>>> getPosts({
    CacheStrategy strategy = CacheStrategy.networkFirst,
    bool forceRefresh = false,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/posts',
      options: Options(
        extra: {
          'cacheStrategy': strategy,
          if (forceRefresh) 'forceRefresh': true,
        },
      ),
    );
    return response.data!.cast<Map<String, dynamic>>();
  }

  /// Creates a new post.
  Future<Map<String, dynamic>> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/posts',
      data: {'title': title, 'body': body, 'userId': userId},
    );
    return response.data!;
  }

  /// Clears the cache.
  Future<int> clearCache() => _cacheInterceptor.clearCache();
}
