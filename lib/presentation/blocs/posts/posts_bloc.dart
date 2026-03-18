import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/clear_cache.dart';
import '../../../domain/usecases/create_post.dart';
import '../../../domain/usecases/get_posts.dart';
import 'posts_event.dart';
import 'posts_state.dart';

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  final GetPosts _getPosts;
  final CreatePost _createPost;
  final ClearCache _clearCache;

  PostsBloc({
    required GetPosts getPosts,
    required CreatePost createPost,
    required ClearCache clearCache,
  }) : _getPosts = getPosts,
       _createPost = createPost,
       _clearCache = clearCache,
       super(const PostsInitial()) {
    on<FetchPosts>(_onFetchPosts);
    on<CreateNewPost>(_onCreatePost);
    on<ClearPostsCache>(_onClearCache);
  }

  Future<void> _onFetchPosts(FetchPosts event, Emitter<PostsState> emit) async {
    emit(PostsLoading(strategy: event.strategy));

    final stopwatch = Stopwatch()..start();
    final result = await _getPosts(
      strategy: event.strategy,
      forceRefresh: event.forceRefresh,
    );
    stopwatch.stop();

    result.when(
      success: (posts) => emit(
        PostsLoaded(
          posts: posts,
          strategy: event.strategy,
          duration: stopwatch.elapsed,
        ),
      ),
      failure: (error) =>
          emit(PostsError(error.message, strategy: event.strategy)),
    );
  }

  Future<void> _onCreatePost(
    CreateNewPost event,
    Emitter<PostsState> emit,
  ) async {
    final result = await _createPost(
      title: event.title,
      body: event.body,
      userId: event.userId,
    );

    result.when(
      success: (post) => emit(PostCreated(post)),
      failure: (error) => emit(PostsError(error.message)),
    );
  }

  Future<void> _onClearCache(
    ClearPostsCache event,
    Emitter<PostsState> emit,
  ) async {
    final count = await _clearCache();
    emit(CacheCleared(count));
  }
}
