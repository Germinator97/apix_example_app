import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/post_repository.dart';
import '../../../domain/usecases/clear_cache.dart';
import '../../../domain/usecases/create_post.dart';
import '../../../domain/usecases/delete_post.dart';
import '../../../domain/usecases/get_posts.dart';
import '../../../domain/usecases/invalidate_cache.dart';
import '../../../domain/usecases/patch_post.dart';
import '../../../domain/usecases/update_post.dart';
import '../../../domain/usecases/upload_file.dart';
import 'posts_event.dart';
import 'posts_state.dart';

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final GetPosts _getPosts;
  final CreatePost _createPost;
  final UpdatePost _updatePost;
  final PatchPost _patchPost;
  final DeletePost _deletePost;
  final UploadFile _uploadFile;
  final ClearCache _clearCache;
  final InvalidateCache _invalidate;
  final PostRepository _repository;

  PostsBloc({
    required GetPosts getPosts,
    required CreatePost createPost,
    required UpdatePost updatePost,
    required PatchPost patchPost,
    required DeletePost deletePost,
    required UploadFile uploadFile,
    required ClearCache clearCache,
    required InvalidateCache invalidateCache,
    required PostRepository repository,
  }) : _getPosts = getPosts,
       _createPost = createPost,
       _updatePost = updatePost,
       _patchPost = patchPost,
       _deletePost = deletePost,
       _uploadFile = uploadFile,
       _clearCache = clearCache,
       _invalidate = invalidateCache,
       _repository = repository,
       super(const PostsInitial()) {
    on<FetchPosts>(_onFetchPosts);
    on<CreateNewPost>(_onCreatePost);
    on<UpdateExistingPost>(_onUpdatePost);
    on<PatchExistingPost>(_onPatchPost);
    on<DeleteExistingPost>(_onDeletePost);
    on<UploadDemoFile>(_onUploadFile);
    on<ClearPostsCache>(_onClearCache);
    on<InvalidatePostsUrl>(_onInvalidateUrl);
    on<InvalidatePostsPath>(_onInvalidatePath);
    on<InvalidatePostsByPrefix>(_onInvalidateByPrefix);
    on<InspectCacheKeys>(_onInspectKeys);
  }

  Future<void> _onFetchPosts(FetchPosts event, Emitter<PostsState> emit) async {
    emit(PostsLoading(strategy: event.strategy));
    try {
      final stopwatch = Stopwatch()..start();
      final result = await _getPosts(
        strategy: event.strategy,
        forceRefresh: event.forceRefresh,
      );
      stopwatch.stop();

      if (result.isSuccess) {
        emit(
          PostsLoaded(
            posts: result.valueOrNull!,
            strategy: event.strategy,
            duration: stopwatch.elapsed,
            fromCache: _repository.lastFromCache,
            fromCacheStale: _repository.lastFromCacheStale,
          ),
        );
      } else {
        emit(PostsError(result.errorOrNull!.message, strategy: event.strategy));
      }
    } catch (e) {
      emit(PostsError(e.toString(), strategy: event.strategy));
    }
  }

  Future<void> _onCreatePost(
    CreateNewPost event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final result = await _createPost(
        title: event.title,
        body: event.body,
        userId: event.userId,
      );
      if (result.isSuccess) {
        emit(PostCreated(result.valueOrNull!));
      } else {
        emit(PostsError(result.errorOrNull!.message));
      }
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onUpdatePost(
    UpdateExistingPost event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final result = await _updatePost(
        id: event.id,
        title: event.title,
        body: event.body,
        userId: event.userId,
      );
      if (result.isSuccess) {
        emit(PostUpdated(result.valueOrNull!, verb: 'PUT'));
      } else {
        emit(PostsError(result.errorOrNull!.message));
      }
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onPatchPost(
    PatchExistingPost event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final result = await _patchPost(id: event.id, title: event.title);
      if (result.isSuccess) {
        emit(PostUpdated(result.valueOrNull!, verb: 'PATCH'));
      } else {
        emit(PostsError(result.errorOrNull!.message));
      }
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onDeletePost(
    DeleteExistingPost event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final result = await _deletePost(event.id);
      if (result.isSuccess) {
        emit(PostDeleted(event.id));
      } else {
        emit(PostsError(result.errorOrNull!.message));
      }
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onUploadFile(
    UploadDemoFile event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final size = await event.file.length();
      final result = await _uploadFile(event.file, label: event.label);
      if (result.isSuccess) {
        emit(
          FileUploaded(
            filename: event.file.uri.pathSegments.last,
            sizeBytes: size,
          ),
        );
      } else {
        emit(PostsError(result.errorOrNull!.message));
      }
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onClearCache(
    ClearPostsCache event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final count = await _clearCache();
      emit(CacheCleared(count));
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onInvalidateUrl(
    InvalidatePostsUrl event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final ok = await _invalidate.url(event.url);
      emit(
        CacheInvalidated(
          operation: 'invalidateUrl(${event.url})',
          affected: ok ? 1 : 0,
        ),
      );
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onInvalidatePath(
    InvalidatePostsPath event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final affected = await _invalidate.path(event.path);
      emit(
        CacheInvalidated(
          operation: 'invalidatePath(${event.path})',
          affected: affected,
        ),
      );
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onInvalidateByPrefix(
    InvalidatePostsByPrefix event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final affected = await _invalidate.prefix(event.prefix);
      emit(
        CacheInvalidated(
          operation: 'invalidateByPrefix(${event.prefix})',
          affected: affected,
        ),
      );
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }

  Future<void> _onInspectKeys(
    InspectCacheKeys event,
    Emitter<PostsState> emit,
  ) async {
    try {
      final keys = await _invalidate.keys();
      emit(CacheKeysListed(keys));
    } catch (e) {
      emit(PostsError(e.toString()));
    }
  }
}
