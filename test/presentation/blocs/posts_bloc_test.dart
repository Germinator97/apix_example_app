import 'package:apix/apix.dart' hide Failure;
import 'package:apix_example_app/core/error/failures.dart';
import 'package:apix_example_app/domain/entities/post.dart';
import 'package:apix_example_app/domain/repositories/post_repository.dart';
import 'package:apix_example_app/domain/usecases/clear_cache.dart';
import 'package:apix_example_app/domain/usecases/create_post.dart';
import 'package:apix_example_app/domain/usecases/delete_post.dart';
import 'package:apix_example_app/domain/usecases/get_posts.dart';
import 'package:apix_example_app/domain/usecases/invalidate_cache.dart';
import 'package:apix_example_app/domain/usecases/patch_post.dart';
import 'package:apix_example_app/domain/usecases/update_post.dart';
import 'package:apix_example_app/domain/usecases/upload_file.dart';
import 'package:apix_example_app/presentation/blocs/posts/posts_bloc.dart';
import 'package:apix_example_app/presentation/blocs/posts/posts_event.dart';
import 'package:apix_example_app/presentation/blocs/posts/posts_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetPosts extends Mock implements GetPosts {}

class _MockCreatePost extends Mock implements CreatePost {}

class _MockUpdatePost extends Mock implements UpdatePost {}

class _MockPatchPost extends Mock implements PatchPost {}

class _MockDeletePost extends Mock implements DeletePost {}

class _MockUploadFile extends Mock implements UploadFile {}

class _MockClearCache extends Mock implements ClearCache {}

class _MockInvalidateCache extends Mock implements InvalidateCache {}

class _MockRepo extends Mock implements PostRepository {}

void main() {
  late _MockGetPosts getPosts;
  late _MockCreatePost createPost;
  late _MockUpdatePost updatePost;
  late _MockPatchPost patchPost;
  late _MockDeletePost deletePost;
  late _MockUploadFile uploadFile;
  late _MockClearCache clearCache;
  late _MockInvalidateCache invalidateCache;
  late _MockRepo repo;

  PostsBloc build() => PostsBloc(
    getPosts: getPosts,
    createPost: createPost,
    updatePost: updatePost,
    patchPost: patchPost,
    deletePost: deletePost,
    uploadFile: uploadFile,
    clearCache: clearCache,
    invalidateCache: invalidateCache,
    repository: repo,
  );

  setUpAll(() {
    registerFallbackValue(CacheStrategy.networkFirst);
  });

  setUp(() {
    getPosts = _MockGetPosts();
    createPost = _MockCreatePost();
    updatePost = _MockUpdatePost();
    patchPost = _MockPatchPost();
    deletePost = _MockDeletePost();
    uploadFile = _MockUploadFile();
    clearCache = _MockClearCache();
    invalidateCache = _MockInvalidateCache();
    repo = _MockRepo();
    when(() => repo.lastFromCache).thenReturn(false);
    // Must be stubbed too: PostsBloc reads it on every PostsLoaded, so an
    // unstubbed getter would fail the handler and look like a bloc bug.
    when(() => repo.lastFromCacheStale).thenReturn(false);
  });

  group('FetchPosts', () {
    blocTest<PostsBloc, PostsState>(
      'émet [Loading, Loaded] en cas de succès',
      build: () {
        when(
          () => getPosts(
            strategy: any(named: 'strategy'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer(
          (_) async => Result.success(const [
            Post(id: 1, userId: 1, title: 't', body: 'b'),
          ]),
        );
        return build();
      },
      act: (bloc) => bloc.add(const FetchPosts()),
      expect: () => [
        const PostsLoading(strategy: CacheStrategy.networkFirst),
        isA<PostsLoaded>().having((s) => s.posts.length, 'posts.length', 1),
      ],
    );

    blocTest<PostsBloc, PostsState>(
      'émet [Loading, Error] sur Failure',
      build: () {
        when(
          () => getPosts(
            strategy: any(named: 'strategy'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer((_) async => Result.failure(const NetworkFailure()));
        return build();
      },
      act: (bloc) => bloc.add(const FetchPosts()),
      expect: () => [
        const PostsLoading(strategy: CacheStrategy.networkFirst),
        isA<PostsError>(),
      ],
    );

    blocTest<PostsBloc, PostsState>(
      'émet [Loading, Error] si le usecase throw (handler protégé)',
      build: () {
        when(
          () => getPosts(
            strategy: any(named: 'strategy'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenThrow(StateError('boom'));
        return build();
      },
      act: (bloc) => bloc.add(const FetchPosts()),
      expect: () => [
        const PostsLoading(strategy: CacheStrategy.networkFirst),
        isA<PostsError>(),
      ],
    );
  });

  group('Mutations', () {
    blocTest<PostsBloc, PostsState>(
      'CreateNewPost émet PostCreated',
      build: () {
        when(
          () => createPost(
            title: any(named: 'title'),
            body: any(named: 'body'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => Result.success(
            const Post(id: 9, userId: 1, title: 'T', body: 'B'),
          ),
        );
        return build();
      },
      act: (bloc) =>
          bloc.add(const CreateNewPost(title: 'T', body: 'B', userId: 1)),
      expect: () => [isA<PostCreated>()],
    );

    blocTest<PostsBloc, PostsState>(
      'UpdateExistingPost émet PostUpdated(verb=PUT)',
      build: () {
        when(
          () => updatePost(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            userId: any(named: 'userId'),
          ),
        ).thenAnswer(
          (_) async => Result.success(
            const Post(id: 1, userId: 1, title: 'X', body: 'Y'),
          ),
        );
        return build();
      },
      act: (bloc) => bloc.add(
        const UpdateExistingPost(id: 1, title: 'X', body: 'Y', userId: 1),
      ),
      expect: () => [isA<PostUpdated>().having((s) => s.verb, 'verb', 'PUT')],
    );

    blocTest<PostsBloc, PostsState>(
      'PatchExistingPost émet PostUpdated(verb=PATCH)',
      build: () {
        when(
          () => patchPost(
            id: any(named: 'id'),
            title: any(named: 'title'),
          ),
        ).thenAnswer(
          (_) async => Result.success(
            const Post(id: 1, userId: 1, title: 'P', body: ''),
          ),
        );
        return build();
      },
      act: (bloc) => bloc.add(const PatchExistingPost(id: 1, title: 'P')),
      expect: () => [isA<PostUpdated>().having((s) => s.verb, 'verb', 'PATCH')],
    );

    blocTest<PostsBloc, PostsState>(
      'DeleteExistingPost émet PostDeleted',
      build: () {
        when(
          () => deletePost(any()),
        ).thenAnswer((_) async => Result.success(null));
        return build();
      },
      act: (bloc) => bloc.add(const DeleteExistingPost(1)),
      expect: () => [isA<PostDeleted>().having((s) => s.id, 'id', 1)],
    );
  });

  group('Cache', () {
    blocTest<PostsBloc, PostsState>(
      'ClearPostsCache émet CacheCleared',
      build: () {
        when(() => clearCache()).thenAnswer((_) async => 7);
        return build();
      },
      act: (bloc) => bloc.add(const ClearPostsCache()),
      expect: () => [
        isA<CacheCleared>().having((s) => s.clearedCount, 'count', 7),
      ],
    );

    blocTest<PostsBloc, PostsState>(
      'InvalidatePostsUrl émet CacheInvalidated affected=1 si succès',
      build: () {
        when(() => invalidateCache.url('/posts')).thenAnswer((_) async => true);
        return build();
      },
      act: (bloc) => bloc.add(const InvalidatePostsUrl('/posts')),
      expect: () => [
        isA<CacheInvalidated>().having((s) => s.affected, 'affected', 1),
      ],
    );

    blocTest<PostsBloc, PostsState>(
      'InspectCacheKeys émet CacheKeysListed',
      build: () {
        when(
          () => invalidateCache.keys(),
        ).thenAnswer((_) async => ['GET:https://api.test/posts']);
        return build();
      },
      act: (bloc) => bloc.add(const InspectCacheKeys()),
      expect: () => [
        isA<CacheKeysListed>().having((s) => s.keys.length, 'keys', 1),
      ],
    );
  });
}
