import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../../core/error/wrap_exceptions.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/remote_data_source.dart';

class PostRepositoryImpl implements PostRepository {
  final RemoteDataSource _remoteDataSource;

  PostRepositoryImpl(this._remoteDataSource);

  @override
  bool get lastFromCache => _remoteDataSource.lastFromCache;

  @override
  bool get lastFromCacheStale => _remoteDataSource.lastFromCacheStale;

  @override
  Future<Result<List<Post>, Failure>> getPosts({
    CacheStrategy strategy = CacheStrategy.networkFirst,
    bool forceRefresh = false,
  }) {
    return wrapExceptions(() async {
      final data = await _remoteDataSource.getPosts(
        strategy: strategy,
        forceRefresh: forceRefresh,
      );
      return data.map((e) => e.toEntity()).toList();
    });
  }

  @override
  Future<Result<Post, Failure>> createPost({
    required String title,
    required String body,
    required int userId,
  }) {
    return wrapExceptions(() async {
      final data = await _remoteDataSource.createPost(
        title: title,
        body: body,
        userId: userId,
      );
      return data.toEntity();
    });
  }

  @override
  Future<Result<Post, Failure>> updatePost({
    required int id,
    required String title,
    required String body,
    required int userId,
  }) {
    return wrapExceptions(() async {
      final data = await _remoteDataSource.updatePost(
        id: id,
        title: title,
        body: body,
        userId: userId,
      );
      return data.toEntity();
    });
  }

  @override
  Future<Result<Post, Failure>> patchPost({
    required int id,
    required String title,
  }) {
    return wrapExceptions(() async {
      final data = await _remoteDataSource.patchPost(id: id, title: title);
      return data.toEntity();
    });
  }

  @override
  Future<Result<void, Failure>> deletePost(int id) {
    return wrapExceptions(() async {
      await _remoteDataSource.deletePost(id);
    });
  }

  @override
  Future<int> clearCache() => _remoteDataSource.clearCache();

  @override
  Future<bool> invalidateUrl(String url) =>
      _remoteDataSource.invalidateUrl(url);

  @override
  Future<int> invalidatePath(String path) =>
      _remoteDataSource.invalidatePath(path);

  @override
  Future<int> invalidateByPrefix(String prefix) =>
      _remoteDataSource.invalidateByPrefix(prefix);

  @override
  Future<List<String>> getCacheKeys() => _remoteDataSource.getCacheKeys();
}
