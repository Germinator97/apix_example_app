import 'package:apix/apix.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/local_data_source.dart';
import '../../data/datasources/remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/post_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/usecases/clear_cache.dart';
import '../../domain/usecases/create_post.dart';
import '../../domain/usecases/delete_post.dart';
import '../../domain/usecases/get_posts.dart';
import '../../domain/usecases/get_users.dart';
import '../../domain/usecases/invalidate_cache.dart';
import '../../domain/usecases/patch_post.dart';
import '../../domain/usecases/test_sentry.dart';
import '../../domain/usecases/update_post.dart';
import '../../domain/usecases/upload_file.dart';
import '../../presentation/blocs/envelope/envelope_bloc.dart';
import '../../presentation/blocs/epic11/epic11_bloc.dart';
import '../../presentation/blocs/posts/posts_bloc.dart';
import '../../presentation/blocs/retry_policy/retry_policy_bloc.dart';
import '../../presentation/blocs/sentry/sentry_bloc.dart';
import '../../presentation/blocs/tracking/tracking_bloc.dart';
import '../../presentation/blocs/users/users_bloc.dart';
import '../services/api_client_provider.dart';
import '../services/envelope_demo_client.dart';
import '../services/epic11_demo_client.dart';
import '../services/error_tracking_demo_client.dart';
import '../services/retry_policy_demo_client.dart';

final sl = GetIt.instance;

/// Initializes all dependencies using GetIt.
///
/// Architecture: DataSource → Repository → UseCase → Bloc.
/// Two ApiClient instances are wired in:
/// - the main one against JSONPlaceholder (auth/retry/cache/logging/metrics)
/// - a tiny mocked one for the envelope-API demo (`{data: ...}` payloads)
Future<void> initDependencies() async {
  // Resolved here, not inside apix: the package takes a Directory so it needs
  // no dependency on path_provider.
  final cacheDirectory = await getTemporaryDirectory();

  // ============================================================
  // INFRASTRUCTURE
  // ============================================================
  sl.registerLazySingleton<ApiClientProvider>(
    () => ApiClientProvider(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      cacheDirectory: cacheDirectory,
    ),
  );

  sl.registerLazySingleton<EnvelopeDemoClient>(EnvelopeDemoClient.new);

  sl.registerLazySingleton<Epic11DemoClient>(Epic11DemoClient.new);

  sl.registerLazySingleton<RetryPolicyDemoClient>(RetryPolicyDemoClient.new);

  sl.registerLazySingleton<ErrorTrackingDemoClient>(
    ErrorTrackingDemoClient.new,
  );

  sl.registerLazySingleton<TokenProvider>(
    () => sl<ApiClientProvider>().tokenProvider,
  );

  // ============================================================
  // DATA SOURCES
  // ============================================================
  sl.registerLazySingleton<LocalDataSource>(
    () => LocalDataSource(sl<ApiClientProvider>().tokenProvider),
  );

  sl.registerLazySingleton<RemoteDataSource>(
    () => RemoteDataSource(
      sl<ApiClientProvider>().client,
      sl<ApiClientProvider>().cacheInterceptor,
    ),
  );

  // ============================================================
  // REPOSITORIES
  // ============================================================
  sl.registerLazySingleton<UserRepository>(() => UserRepositoryImpl(sl()));
  sl.registerLazySingleton<PostRepository>(() => PostRepositoryImpl(sl()));
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));

  // ============================================================
  // USE CASES
  // ============================================================
  sl.registerLazySingleton(() => GetUsers(sl()));
  sl.registerLazySingleton(() => GetPosts(sl()));
  sl.registerLazySingleton(() => CreatePost(sl()));
  sl.registerLazySingleton(() => UpdatePost(sl()));
  sl.registerLazySingleton(() => PatchPost(sl()));
  sl.registerLazySingleton(() => DeletePost(sl()));
  sl.registerLazySingleton(() => UploadFile(sl()));
  sl.registerLazySingleton(() => ClearCache(sl()));
  sl.registerLazySingleton(() => InvalidateCache(sl()));
  sl.registerLazySingleton(() => TestSentry(sl()));

  // ============================================================
  // BLOCS
  // ============================================================
  sl.registerFactory(() => UsersBloc(getUsers: sl()));
  sl.registerFactory(
    () => PostsBloc(
      getPosts: sl(),
      createPost: sl(),
      updatePost: sl(),
      patchPost: sl(),
      deletePost: sl(),
      uploadFile: sl(),
      clearCache: sl(),
      invalidateCache: sl(),
      repository: sl(),
    ),
  );
  sl.registerFactory(() => EnvelopeBloc(client: sl()));
  sl.registerFactory(() => Epic11Bloc(client: sl()));
  sl.registerFactory(() => RetryPolicyBloc(client: sl()));
  sl.registerFactory(() => TrackingBloc(client: sl()));
  sl.registerFactory(() => SentryBloc(testSentry: sl()));
}
