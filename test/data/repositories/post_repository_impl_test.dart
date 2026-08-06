import 'package:apix/apix.dart' hide Failure;
import 'package:apix_example_app/core/error/failures.dart';
import 'package:apix_example_app/data/datasources/remote_data_source.dart';
import 'package:apix_example_app/data/models/post.dart';
import 'package:apix_example_app/data/repositories/post_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements RemoteDataSource {}

void main() {
  late _MockRemote remote;
  late PostRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(CacheStrategy.networkFirst);
  });

  setUp(() {
    remote = _MockRemote();
    repo = PostRepositoryImpl(remote);
  });

  group('PostRepositoryImpl.getPosts', () {
    test('maps PostModel list to Post entities on success', () async {
      when(
        () => remote.getPosts(
          strategy: any(named: 'strategy'),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer(
        (_) async => const [
          PostModel(id: 1, userId: 1, title: 'a', body: 'A'),
          PostModel(id: 2, userId: 2, title: 'b', body: 'B'),
        ],
      );

      final result = await repo.getPosts();

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, hasLength(2));
      expect(result.valueOrNull!.first.title, 'a');
    });

    test('UnauthorizedException → UnauthorizedFailure', () async {
      when(
        () => remote.getPosts(
          strategy: any(named: 'strategy'),
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenThrow(const UnauthorizedException());

      final result = await repo.getPosts();

      expect(result.errorOrNull, isA<UnauthorizedFailure>());
    });

    test(
      'TimeoutException → UnavailableFailure (regression of "on (T1,T2)")',
      () async {
        when(
          () => remote.getPosts(
            strategy: any(named: 'strategy'),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenThrow(const TimeoutException(message: 'timeout'));

        final result = await repo.getPosts();

        expect(result.errorOrNull, isA<UnavailableFailure>());
      },
    );
  });

  group('PostRepositoryImpl mutations', () {
    test('createPost forwards to remote', () async {
      when(
        () => remote.createPost(title: 'T', body: 'B', userId: 1),
      ).thenAnswer(
        (_) async => const PostModel(id: 99, userId: 1, title: 'T', body: 'B'),
      );

      final result = await repo.createPost(title: 'T', body: 'B', userId: 1);

      expect(result.valueOrNull!.id, 99);
    });

    test('deletePost succeeds with empty value', () async {
      when(() => remote.deletePost(7)).thenAnswer((_) async {});

      final result = await repo.deletePost(7);

      expect(result.isSuccess, isTrue);
    });

    test('patchPost wraps NotFound into NotFoundFailure', () async {
      when(
        () => remote.patchPost(id: 1, title: 'T'),
      ).thenThrow(const NotFoundException());

      final result = await repo.patchPost(id: 1, title: 'T');

      expect(result.errorOrNull, isA<NotFoundFailure>());
    });
  });

  group('PostRepositoryImpl cache passthrough', () {
    test('clearCache delegates to remote', () async {
      when(() => remote.clearCache()).thenAnswer((_) async => 5);
      expect(await repo.clearCache(), 5);
    });

    test('invalidateUrl delegates to remote', () async {
      when(() => remote.invalidateUrl('/posts')).thenAnswer((_) async => true);
      expect(await repo.invalidateUrl('/posts'), isTrue);
    });

    test('invalidatePath delegates to remote', () async {
      when(() => remote.invalidatePath('/posts')).thenAnswer((_) async => 3);
      expect(await repo.invalidatePath('/posts'), 3);
    });

    test('invalidateByPrefix delegates to remote', () async {
      when(() => remote.invalidateByPrefix('GET:')).thenAnswer((_) async => 7);
      expect(await repo.invalidateByPrefix('GET:'), 7);
    });

    test('getCacheKeys delegates to remote', () async {
      when(
        () => remote.getCacheKeys(),
      ).thenAnswer((_) async => ['GET:https://x/posts']);
      expect(await repo.getCacheKeys(), ['GET:https://x/posts']);
    });

    test('lastFromCache mirrors remote', () {
      when(() => remote.lastFromCache).thenReturn(true);
      expect(repo.lastFromCache, isTrue);
    });

    test('lastFromCacheStale mirrors remote', () {
      when(() => remote.lastFromCacheStale).thenReturn(true);
      expect(repo.lastFromCacheStale, isTrue);
    });
  });
}
