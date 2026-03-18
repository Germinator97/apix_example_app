import 'package:apix/apix.dart';
import 'package:equatable/equatable.dart';

abstract class PostsEvent extends Equatable {
  const PostsEvent();

  @override
  List<Object?> get props => [];
}

class FetchPosts extends PostsEvent {
  final CacheStrategy strategy;
  final bool forceRefresh;

  const FetchPosts({
    this.strategy = CacheStrategy.networkFirst,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [strategy, forceRefresh];
}

class CreateNewPost extends PostsEvent {
  final String title;
  final String body;
  final int userId;

  const CreateNewPost({
    required this.title,
    required this.body,
    required this.userId,
  });

  @override
  List<Object?> get props => [title, body, userId];
}

class ClearPostsCache extends PostsEvent {
  const ClearPostsCache();
}
