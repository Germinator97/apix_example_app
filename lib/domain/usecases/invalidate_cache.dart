import '../repositories/post_repository.dart';

/// Targeted cache invalidation operations exposed by [PostRepository].
///
/// Each method maps 1:1 to a `CacheInterceptor` invalidation API.
class InvalidateCache {
  final PostRepository _repository;

  InvalidateCache(this._repository);

  /// Invalidates a single relative URL (resolved against baseUrl by apix).
  Future<bool> url(String url) => _repository.invalidateUrl(url);

  /// Invalidates every cache key whose URL contains [pathPattern].
  Future<int> path(String pathPattern) =>
      _repository.invalidatePath(pathPattern);

  /// Invalidates every cache key starting with [prefix] (e.g. `GET:https://...`).
  Future<int> prefix(String prefix) => _repository.invalidateByPrefix(prefix);

  /// Returns the current cache keys (useful for debugging).
  Future<List<String>> keys() => _repository.getCacheKeys();
}
