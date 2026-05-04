import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Use case for partially updating a post (PATCH).
class PatchPost {
  final PostRepository _repository;

  PatchPost(this._repository);

  Future<Result<Post, Failure>> call({required int id, required String title}) {
    return _repository.patchPost(id: id, title: title);
  }
}
