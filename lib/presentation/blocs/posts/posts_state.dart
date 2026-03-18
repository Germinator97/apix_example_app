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

  const PostsLoaded({
    required this.posts,
    required this.strategy,
    required this.duration,
  });

  @override
  List<Object?> get props => [posts, strategy, duration];
}

class PostCreated extends PostsState {
  final Post post;

  const PostCreated(this.post);

  @override
  List<Object?> get props => [post];
}

class CacheCleared extends PostsState {
  final int clearedCount;

  const CacheCleared(this.clearedCount);

  @override
  List<Object?> get props => [clearedCount];
}

class PostsError extends PostsState {
  final String message;
  final CacheStrategy? strategy;

  const PostsError(this.message, {this.strategy});

  @override
  List<Object?> get props => [message, strategy];
}
