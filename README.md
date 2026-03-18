# Apix Example

A Flutter app demonstrating all major features of the **apix** package.

## Features Demonstrated

### 0. Sentry Integration (`lib/main.dart`)

Full Sentry error tracking setup:

```dart
void main() async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  await SentrySetup.init(
    options: SentrySetupOptions(
      dsn: 'https://example@sentry.io/example',
      environment: 'development',
      filterNetworkNoise: true,
      anrEnabled: true,
    ),
    appRunner: () async {
      runApp(const ApixExampleApp());
    },
  );
}
```

### 1. API Client Setup (`lib/api/api_service.dart`)

Shows how to create a fully configured API client:

```dart
final client = ApiClientFactory.create(
  baseUrl: 'https://jsonplaceholder.typicode.com',
  connectTimeout: const Duration(seconds: 30),
  headers: {'X-App-Version': '1.0.0'},
);
```

### 2. Secure Token Storage (`lib/data/datasources/local_data_source.dart`)

Uses apix's built-in `SecureTokenProvider` for zero-boilerplate secure storage:

```dart
// LocalDataSource wraps SecureTokenProvider
final localDataSource = LocalDataSource();

// Access the token provider for auth config
final tokenProvider = localDataSource.tokenProvider;

// Store additional secrets using shared storage
await localDataSource.writeSecret('firebase_token', token);
```

With simplified refresh flow:

```dart
AuthConfig(
  tokenProvider: tokenProvider,
  refreshEndpoint: '/auth/refresh',
  onTokenRefreshed: (response) async {
    final data = response.data as Map<String, dynamic>;
    await tokenProvider.saveTokens(
      data['access_token'],
      data['refresh_token'],
    );
  },
)
```

### 3. Retry Logic

Automatic retries with exponential backoff:

```dart
final retryInterceptor = RetryInterceptor(
  config: const RetryConfig(
    maxAttempts: 3,
    retryStatusCodes: [408, 429, 500, 502, 503, 504],
    baseDelayMs: 1000,
    multiplier: 2.0,
  ),
  dio: client.dio,
);
```

### 4. Caching

Multiple caching strategies:

```dart
// Cache-first for static data
final response = await client.get(
  '/posts',
  options: Options(extra: {
    'cacheStrategy': CacheStrategy.cacheFirst,
  }),
);
```

### 5. Error Handling with Result

Functional error handling without try/catch:

```dart
final result = await api.getUsersSafe();

result.when(
  success: (users) => print('Got ${users.length} users'),
  failure: (error) => print('Error: ${error.message}'),
);
```

### 6. Logging & Metrics

Request logging and performance tracking:

```dart
final loggerInterceptor = LoggerInterceptor(
  config: const LoggerConfig(
    level: LogLevel.info,
    redactedHeaders: ['Authorization'],
  ),
);

final metricsInterceptor = MetricsInterceptor(
  config: MetricsConfig(
    onMetrics: (metrics) {
      print('${metrics.method} ${metrics.path} ${metrics.durationMs}ms');
    },
  ),
);
```

### 7. Sentry Interceptor

HTTP error capturing and breadcrumbs:

```dart
final sentryInterceptor = SentryInterceptor(
  config: SentryConfig(
    captureStatusCodes: {500, 501, 502, 503, 504},
    captureException: (exception, {stackTrace, extra, tags}) async {
      await Sentry.captureException(exception, stackTrace: stackTrace);
    },
    addBreadcrumb: (data) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: data['message'] as String?,
        category: data['category'] as String?,
      ));
    },
  ),
);
```

## Supported Platforms

- ✅ iOS
- ✅ Android

## Running the Example

```bash
cd apix_example_app
flutter pub get
flutter run
```

## API Used

This example uses [JSONPlaceholder](https://jsonplaceholder.typicode.com/),
a free fake REST API for testing.

## Structure

```
apix_example_app/
├── lib/
│   ├── main.dart                     # App entry with SentrySetup
│   ├── core/
│   │   ├── di/injection_container.dart   # GetIt dependency injection
│   │   ├── network/api_client_factory.dart # Full interceptor setup
│   │   └── theme/app_theme.dart
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── local_data_source.dart    # SecureTokenProvider wrapper
│   │   │   └── remote_data_source.dart
│   │   └── repositories/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   └── presentation/
│       ├── blocs/
│       ├── screens/home_screen.dart
│       └── widgets/
└── pubspec.yaml
```
