import 'package:apix/apix.dart';
import 'package:equatable/equatable.dart';

import '../../../domain/entities/post.dart';

abstract class PostsState extends Equatable {
  const PostsState();

  @override
  List<Object?> get props => [];
}

class PostsInitial extends PostsState {
  const PostsInitial();
}

class PostsLoading extends PostsState {
  final CacheStrategy strategy;

  const PostsLoading({required this.strategy});

  @override
  List<Object?> get props => [strategy];
}

class PostsLoaded extends PostsState {
  final List<Post> posts;
  final CacheStrategy strategy;
  final Duration duration;
  final bool fromCache;

  /// True when the cached body served was already expired.
  final bool fromCacheStale;

  const PostsLoaded({
    required this.posts,
    required this.strategy,
    required this.duration,
    required this.fromCache,
    this.fromCacheStale = false,
  });

  @override
  List<Object?> get props => [
    posts,
    strategy,
    duration,
    fromCache,
    fromCacheStale,
  ];
}

class PostCreated extends PostsState {
  final Post post;

  const PostCreated(this.post);

  @override
  List<Object?> get props => [post];
}

class PostUpdated extends PostsState {
  final Post post;
  final String verb;

  const PostUpdated(this.post, {required this.verb});

  @override
  List<Object?> get props => [post, verb];
}

class PostDeleted extends PostsState {
  final int id;

  const PostDeleted(this.id);

  @override
  List<Object?> get props => [id];
}

class FileUploaded extends PostsState {
  final String filename;
  final int sizeBytes;

  const FileUploaded({required this.filename, required this.sizeBytes});

  @override
  List<Object?> get props => [filename, sizeBytes];
}

class CacheCleared extends PostsState {
  final int clearedCount;

  const CacheCleared(this.clearedCount);

  @override
  List<Object?> get props => [clearedCount];
}

class CacheInvalidated extends PostsState {
  final String operation;
  final int affected;

  const CacheInvalidated({required this.operation, required this.affected});

  @override
  List<Object?> get props => [operation, affected];
}

class CacheKeysListed extends PostsState {
  final List<String> keys;

  const CacheKeysListed(this.keys);

  @override
  List<Object?> get props => [keys];
}

class PostsError extends PostsState {
  final String message;
  final CacheStrategy? strategy;

  const PostsError(this.message, {this.strategy});

  @override
  List<Object?> get props => [message, strategy];
}
