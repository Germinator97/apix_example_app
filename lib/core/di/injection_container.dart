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
import '../network/api_client_factory.dart';

final sl = GetIt.instance;

/// Initializes all dependencies using GetIt.
Future<void> initDependencies() async {
  // ============================================================
  // DATA SOURCES
  // ============================================================
  // LocalDataSource now uses apix's SecureTokenProvider internally
  // No need to inject FlutterSecureStorage manually
  sl.registerLazySingleton<LocalDataSource>(() => LocalDataSource());

  // API Client Factory
  sl.registerLazySingleton<AppApiClientFactory>(
    () => AppApiClientFactory(sl()),
  );

  // Create API client and cache interceptor
  final apiSetup = sl<AppApiClientFactory>().create();
  sl.registerLazySingleton(() => apiSetup.client);
  sl.registerLazySingleton(() => apiSetup.cacheInterceptor);

  sl.registerLazySingleton<RemoteDataSource>(
    () => RemoteDataSource(sl(), sl()),
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
