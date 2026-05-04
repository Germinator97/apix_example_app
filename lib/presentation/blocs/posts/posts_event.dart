import 'dart:io';

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

class UpdateExistingPost extends PostsEvent {
  final int id;
  final String title;
  final String body;
  final int userId;

  const UpdateExistingPost({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  @override
  List<Object?> get props => [id, title, body, userId];
}

class PatchExistingPost extends PostsEvent {
  final int id;
  final String title;

  const PatchExistingPost({required this.id, required this.title});

  @override
  List<Object?> get props => [id, title];
}

class DeleteExistingPost extends PostsEvent {
  final int id;

  const DeleteExistingPost(this.id);

  @override
  List<Object?> get props => [id];
}

class UploadDemoFile extends PostsEvent {
  final File file;
  final String label;

  const UploadDemoFile(this.file, {this.label = 'demo'});

  @override
  List<Object?> get props => [file.path, label];
}

class ClearPostsCache extends PostsEvent {
  const ClearPostsCache();
}

class InvalidatePostsUrl extends PostsEvent {
  final String url;

  const InvalidatePostsUrl(this.url);

  @override
  List<Object?> get props => [url];
}

class InvalidatePostsPath extends PostsEvent {
  final String path;

  const InvalidatePostsPath(this.path);

  @override
  List<Object?> get props => [path];
}

class InvalidatePostsByPrefix extends PostsEvent {
  final String prefix;

  const InvalidatePostsByPrefix(this.prefix);

  @override
  List<Object?> get props => [prefix];
}

class InspectCacheKeys extends PostsEvent {
  const InspectCacheKeys();
}
