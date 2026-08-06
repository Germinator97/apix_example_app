# Apix Example

A Flutter app demonstrating the **apix** package, wired the way a real app
would be: Clean Architecture (data → domain → presentation), BLoC, and GetIt.

The app depends on apix by **path** (`../apix`), so it always runs against the
working copy of the package — which is exactly why it is CI-gated (see
`.github/workflows/ci.yaml`): a change in apix must not be able to drift this
app in silence.

Every snippet below is lifted from the file named in its heading.

## Features Demonstrated

### 0. Sentry setup (`lib/main.dart`)

```dart
await SentrySetup.init(
  options: SentrySetupOptions(
    dsn: 'YOUR_DSN_HERE',
    environment: 'development',
    tracesSampleRate: 0.0,
    profilesSampleRate: 0.0,
    replayOnErrorSampleRate: 0.0,
    replaySessionSampleRate: 0.0,
    // v2.2: escape hatch for SentryFlutterOptions apix doesn't surface.
    configureOptions: (sentryOptions) {
      sentryOptions.maxBreadcrumbs = 200;
    },
  ),
  appRunner: () async {
    runApp(const ApixExampleApp());
  },
);
```

`SentrySetupOptions.development(...)` is the shorter form, but it does **not**
forward `configureOptions`, so the options are spelled out here.

### 1. Client setup (`lib/core/services/api_client_provider.dart`)

One declarative `ApiClientFactory.create` call wires auth, retry, logging,
error tracking and metrics. The cache interceptor is passed in as a custom
interceptor so the app can hold the *same* instance it uses for invalidation:

```dart
final c = ApiClientFactory.create(
  baseUrl: baseUrl,
  authConfig: _authConfig,
  retryConfig: const RetryConfig(...),
  loggerConfig: LoggerConfig(...),
  errorTrackingConfig: ErrorTrackingConfig(...),
  metricsConfig: MetricsConfig(...),
  strictContentType: true,
  interceptors: [cacheInterceptor],
);

// Required for `invalidateUrl(<relative>)` to resolve against baseUrl.
cacheInterceptor.setDio(c.dio);
```

### 2. Secure token storage (`lib/data/datasources/local_data_source.dart`)

`SecureTokenProvider` gives zero-boilerplate secure storage, and the same
backing store is reusable for other secrets:

```dart
await localDataSource.writeSecret('firebase_token', token);
```

The simplified refresh flow is configured in `ApiClientProvider`: a
`refreshEndpoint` plus `onTokenRefreshed` to persist, and `onAuthFailure` to
clear the session and report to Sentry.

### 3. Retry — method-aware since apix 2.3.0 (`lib/core/services/retry_policy_demo_client.dart`)

Retry combines exponential backoff, `Retry-After`, **and** an idempotency
guard. `RetryConfig.retryableMethods` defaults to the idempotent methods of
RFC 7231 §4.2.2 — `{GET, HEAD, OPTIONS, TRACE, PUT, DELETE}` — so **`POST` and
`PATCH` are not replayed**. Replaying a write after a `5xx` the server may
already have committed (a gateway `502`/`504` following an order) would
duplicate the side effect.

The app's own writes (`createPost`, `patchPost`, `uploadFile`) are therefore
never retried. To replay one anyway, opt in per request — and make the replay
safe with an idempotency key:

```dart
await _client.post<dynamic>(
  '/flaky',
  data: {'quantity': 2},
  options: Options(
    headers: {'Idempotency-Key': 'demo-fixed-key-0001'},
    extra: {forceRetryKey: true},
  ),
);
```

`forceRetry()` overrides the method guard **only**: the status-code guard, the
no-response network guard and `maxAttempts` still apply, and `disableRetry()`
still wins over it.

The **🔁 v2.3 — Method-aware retry** section of the home screen runs three
probes against an always-`503` route and reports how many times the server was
actually hit: `GET` → replayed, `POST` → hit once, `POST` + `forceRetry()` →
replayed. `test/retry/retry_policy_test.dart` asserts both the policy and the
observed behaviour, so widening `retryableMethods` fails the suite.

### 4. Caching (`lib/data/datasources/remote_data_source.dart`)

Per-request strategy override, plus the provenance of what came back:

```dart
final response = await _client.get<dynamic>(
  '/posts',
  options: Options(extra: {'cacheStrategy': effective}),
);
_lastFromCache = response.isFromCache;
_lastFromCacheStale = response.isStale;
```

Since apix 3.0.0, `cacheFirst` serves the cache **even when expired** and
refreshes in the background, and `networkFirst` falls back to a possibly
expired entry when the network is gone. Both flag it with `isStale`, which the
app carries all the way to the UI: the badge on the post list reads *"from
cache"* or *"from earlier — refreshing"*, and the status bar says so too.
The wording differs on purpose — the second one changes what the user should
do with the numbers on screen.

`clearCache`, `invalidateUrl`, `invalidatePath`, `invalidateByPrefix` and
`getCacheKeys` are all exercised from the *Cache Actions* section of the home
screen.

The app's cache is **persistent**: it uses `FileCacheStorage`, wired in
`ApiClientProvider` from a directory the app resolves with `path_provider` and
hands to apix (which deliberately depends on neither).

```dart
storage: FileCacheStorage(
  Directory('${cacheDirectory.path}/apix_cache'),
  maxEntries: 100,
),
```

**See it for yourself**: fetch posts, kill the app, reopen it. The status bar
reports `💾 Restored N cache entries from disk` on launch, and *Inspect Keys*
lists them. With the default `InMemoryCacheStorage` that count is 0 on every
cold start — which is exactly when the wait is most visible.

The cap is deliberate: a process cache disappears when the app closes, a disk
cache does not. Pass `maxEntries: null` to opt out. Expired entries are evicted
before valid ones.

> ⚠️ Entries are stored in **clear text**. JSONPlaceholder posts are public
> sample data; this would be the wrong place for anything carrying identity or
> money.

### 5. Error handling (`lib/core/error/wrap_exceptions.dart`)

Typed apix exceptions are mapped to domain `Failure`s at the repository
boundary, so the BLoCs never see an `ApiException`:

```dart
final result = await wrapExceptions(() => _remoteDataSource.getPosts());
```

apix's `ErrorMapperInterceptor` specialises `401`/`403`/`404` into
`UnauthorizedException` / `ForbiddenException` / `NotFoundException`, maps
every other `4xx` to `ClientException` and every `5xx` to `ServerException`, so
`on ClientException` / `on ServerException` are usable for whole-category
handling.

### 6. Envelope API (`lib/core/services/envelope_demo_client.dart`)

`{"payload": ...}` responses unwrapped by the `*Data` family:
`getAndDecodeData`, `getListAndDecodeData`, `getListAndParseData`,
`postAndDecodeData`.

### 7. Robustness — apix 2.1 (`lib/core/services/epic11_demo_client.dart`)

Four failure modes, each surfaced as a typed exception:

| Route | Raises |
|---|---|
| `/malformed-json` | `ParsingException` |
| `/captive-portal` (returns `text/html`) | `UnexpectedContentTypeException` |
| `/business-error` (`200` + `{"success": false}`) | custom `BusinessException` via `responseValidator` |
| `/throttled` (`503` + `Retry-After: 1`) | succeeds after honouring the header |

Plus a deliberately broken `TokenProvider` to raise `TokenProviderException`.

### 8. Error tracking (`lib/core/services/api_client_provider.dart`)

Since apix 3.0.0, `ErrorTrackingConfig.onError` receives the **typed**
`ApiException`, so Sentry files a 500 (`ServerException`) and a 404
(`NotFoundException`) as separate issues rather than lumping everything under
`DioException`.

Transport failures are then filtered as network noise: tap a cache strategy
with the network down and the status bar reports
`❌ Error: Service temporairement indisponible` with `· connectionError`, but
**nothing reaches Sentry** — a user's dropped connection is not an incident.
Genuine server and client errors always do.

### 9. Logging & metrics (`lib/core/services/api_client_provider.dart`)

Both are declarative on the factory call; the metrics callback feeds the
status bar at the top of the screen:

```dart
metricsConfig: MetricsConfig(
  onMetrics: (metrics) {
    lastMetrics = metrics;
    ...
  },
),
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

## Checks

```bash
dart format --set-exit-if-changed lib test
dart analyze --fatal-infos lib test
flutter test
```

## API Used

This example uses [JSONPlaceholder](https://jsonplaceholder.typicode.com/), a
free fake REST API for testing. The demo clients in `lib/core/services/`
(`envelope`, `epic11`, `retry_policy`) run against in-memory mock adapters
instead, so their scenarios are deterministic and offline.

## Structure

```
apix_example_app/
├── lib/
│   ├── main.dart                            # Entry point + SentrySetup
│   ├── core/
│   │   ├── di/injection_container.dart      # GetIt wiring
│   │   ├── error/                           # Failures + wrapExceptions
│   │   ├── services/
│   │   │   ├── api_client_provider.dart     # The real, fully-wired client
│   │   │   ├── envelope_demo_client.dart    # {"payload": ...} demo
│   │   │   ├── epic11_demo_client.dart      # v2.1 robustness demo
│   │   │   └── retry_policy_demo_client.dart# v2.3 method-aware retry demo
│   │   └── theme/app_theme.dart
│   ├── data/
│   │   ├── datasources/                     # local (secure storage) + remote
│   │   ├── models/
│   │   └── repositories/
│   ├── domain/                              # entities, repositories, usecases
│   └── presentation/
│       ├── blocs/                           # users, posts, envelope,
│       │                                    # epic11, retry_policy, sentry
│       ├── screens/home_screen.dart
│       └── widgets/
└── test/
```
