import 'package:apix/apix.dart';
import 'package:get_it/get_it.dart';

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
import '../../domain/usecases/get_posts.dart';
import '../../domain/usecases/get_users.dart';
import '../../domain/usecases/test_sentry.dart';
import '../../presentation/blocs/posts/posts_bloc.dart';
import '../../presentation/blocs/sentry/sentry_bloc.dart';
import '../../presentation/blocs/users/users_bloc.dart';
import '../services/api_client_provider.dart';

final sl = GetIt.instance;

/// Initializes all dependencies using GetIt.
///
/// Architecture: DataSource → Repository → UseCase → Bloc
Future<void> initDependencies() async {
  // ============================================================
  // INFRASTRUCTURE (ApiX configuration)
  // ============================================================
  sl.registerLazySingleton<ApiClientProvider>(
    () => ApiClientProvider(baseUrl: 'https://jsonplaceholder.typicode.com'),
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
  sl.registerLazySingleton(() => TestSentry(sl()));
  sl.registerLazySingleton(() => CreatePost(sl()));
  sl.registerLazySingleton(() => ClearCache(sl()));

  // ============================================================
  // BLOCS
  // ============================================================
  sl.registerFactory(() => UsersBloc(getUsers: sl()));
  sl.registerFactory(
    () => PostsBloc(getPosts: sl(), createPost: sl(), clearCache: sl()),
  );
  sl.registerFactory(() => SentryBloc(testSentry: sl()));
}
