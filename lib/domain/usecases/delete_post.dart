import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../repositories/post_repository.dart';

/// Use case for deleting a post (DELETE).
class DeletePost {
  final PostRepository _repository;

  DeletePost(this._repository);

  Future<Result<void, Failure>> call(int id) => _repository.deletePost(id);
}
