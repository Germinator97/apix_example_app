import 'package:apix/apix.dart';

import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Use case for creating a new post.
class CreatePost {
  final PostRepository _repository;

  CreatePost(this._repository);

  Future<Result<Post, ApiException>> call({
    required String title,
    required String body,
    required int userId,
  }) {
    return _repository.createPost(title: title, body: body, userId: userId);
  }
}
