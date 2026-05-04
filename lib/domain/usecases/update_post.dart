import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Use case for replacing an existing post (PUT).
class UpdatePost {
  final PostRepository _repository;

  UpdatePost(this._repository);

  Future<Result<Post, Failure>> call({
    required int id,
    required String title,
    required String body,
    required int userId,
  }) {
    return _repository.updatePost(
      id: id,
      title: title,
      body: body,
      userId: userId,
    );
  }
}
