import 'package:apix/apix.dart';

import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/remote_data_source.dart';

/// Implementation of PostRepository using RemoteDataSource.
class PostRepositoryImpl implements PostRepository {
  final RemoteDataSource _remoteDataSource;

  PostRepositoryImpl(this._remoteDataSource);

  @override
  Future<Result<List<Post>, ApiException>> getPosts({
    CacheStrategy strategy = CacheStrategy.networkFirst,
    bool forceRefresh = false,
  }) async {
    try {
      final data = await _remoteDataSource.getPosts(
        strategy: strategy,
        forceRefresh: forceRefresh,
      );
      final posts = data.map(_mapToPost).toList();
      return Success(posts);
    } on ApiException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiException(message: e.toString()));
    }
  }

  @override
  Future<Result<Post, ApiException>> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    try {
      final data = await _remoteDataSource.createPost(
        title: title,
        body: body,
        userId: userId,
      );
      return Success(_mapToPost(data));
    } on ApiException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(ApiException(message: e.toString()));
    }
  }

  @override
  Future<int> clearCache() => _remoteDataSource.clearCache();

  Post _mapToPost(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}
