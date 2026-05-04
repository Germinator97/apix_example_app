import '../repositories/post_repository.dart';

/// Use case for clearing the entire response cache.
class ClearCache {
  final PostRepository _repository;

  ClearCache(this._repository);

  Future<int> call() => _repository.clearCache();
}
