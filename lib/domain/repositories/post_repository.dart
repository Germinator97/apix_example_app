import 'package:apix/apix.dart';

import '../entities/post.dart';

/// Repository interface for post operations.
abstract class PostRepository {
  /// Fetches all posts with configurable cache strategy.
  Future<Result<List<Post>, ApiException>> getPosts({
    CacheStrategy strategy,
    bool forceRefresh,
  });

  /// Creates a new post.
  Future<Result<Post, ApiException>> createPost({
    required String title,
    required String body,
    required int userId,
  });

  /// Clears the cache and returns the number of cleared entries.
  Future<int> clearCache();
}
