import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../../core/error/wrap_exceptions.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../datasources/remote_data_source.dart';

/// Implementation of PostRepository using RemoteDataSource.
///
/// Uses [wrapExceptions] to convert ApiException to user-friendly Failure.
class PostRepositoryImpl implements PostRepository {
  final RemoteDataSource _remoteDataSource;

  PostRepositoryImpl(this._remoteDataSource);

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
  Future<int> clearCache() => _remoteDataSource.clearCache();
}
