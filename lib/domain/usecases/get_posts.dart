import 'package:apix/apix.dart';

import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Use case for fetching posts with cache strategy.
class GetPosts {
  final PostRepository _repository;

  GetPosts(this._repository);

  Future<Result<List<Post>, ApiException>> call({
    CacheStrategy strategy = CacheStrategy.networkFirst,
    bool forceRefresh = false,
  }) {
    return _repository.getPosts(strategy: strategy, forceRefresh: forceRefresh);
  }
}
