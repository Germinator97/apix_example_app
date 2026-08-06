import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../entities/post.dart';

/// Repository interface for post operations.
abstract class PostRepository {
  /// Fetches all posts with configurable cache strategy.
  Future<Result<List<Post>, Failure>> getPosts({
    CacheStrategy strategy,
    bool forceRefresh,
  });

  /// Creates a new post.
  Future<Result<Post, Failure>> createPost({
    required String title,
    required String body,
    required int userId,
  });

  /// Replaces an existing post (PUT).
  Future<Result<Post, Failure>> updatePost({
    required int id,
    required String title,
    required String body,
    required int userId,
  });

  /// Patches an existing post (PATCH).
  Future<Result<Post, Failure>> patchPost({
    required int id,
    required String title,
  });

  /// Deletes a post (DELETE).
  Future<Result<void, Failure>> deletePost(int id);

  /// Whether the last [getPosts] call was served from cache.
  bool get lastFromCache;

  /// Whether that cached response was past its TTL (apix 3.0.0 `isStale`).
  bool get lastFromCacheStale;

  // ============================================================
  // CACHE INVALIDATION (apix CacheInterceptor surface)
  // ============================================================

  /// Clears every cached entry. Returns the number of cleared entries.
  Future<int> clearCache();

  /// Invalidates all cache entries for a single relative URL.
  Future<bool> invalidateUrl(String url);

  /// Invalidates all cache entries whose key contains the given path.
  Future<int> invalidatePath(String path);

  /// Invalidates all cache entries whose key starts with the given prefix.
  Future<int> invalidateByPrefix(String prefix);

  /// Returns the current set of cache keys.
  Future<List<String>> getCacheKeys();
}
