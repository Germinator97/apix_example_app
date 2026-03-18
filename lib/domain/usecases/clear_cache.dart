import '../repositories/post_repository.dart';

/// Use case for clearing the cache.
class ClearCache {
  final PostRepository _repository;

  ClearCache(this._repository);

  Future<int> call() {
    return _repository.clearCache();
  }
}
