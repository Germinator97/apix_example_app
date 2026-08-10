import 'dart:io';

import 'package:apix/apix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/di/injection_container.dart';
import '../../core/services/api_client_provider.dart';
import '../../core/services/error_tracking_demo_client.dart';
import '../../core/services/retry_policy_demo_client.dart';
import '../../core/services/v4_demo_client.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/envelope/envelope_bloc.dart';
import '../blocs/envelope/envelope_event.dart';
import '../blocs/envelope/envelope_state.dart';
import '../blocs/epic11/epic11_bloc.dart';
import '../blocs/epic11/epic11_event.dart';
import '../blocs/epic11/epic11_state.dart';
import '../blocs/posts/posts_bloc.dart';
import '../blocs/posts/posts_event.dart';
import '../blocs/posts/posts_state.dart';
import '../blocs/retry_policy/retry_policy_bloc.dart';
import '../blocs/v4/v4_state.dart';
import '../blocs/v4/v4_event.dart';
import '../blocs/v4/v4_bloc.dart';
import '../blocs/retry_policy/retry_policy_event.dart';
import '../blocs/retry_policy/retry_policy_state.dart';
import '../blocs/sentry/sentry_bloc.dart';
import '../blocs/sentry/sentry_event.dart';
import '../blocs/sentry/sentry_state.dart';
import '../blocs/tracking/tracking_bloc.dart';
import '../blocs/users/users_bloc.dart';
import '../blocs/users/users_event.dart';
import '../blocs/users/users_state.dart';
import '../widgets/cache_strategy_selector.dart';
import '../widgets/post_list.dart';
import '../widgets/status_bar.dart';
import '../widgets/user_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<UsersBloc>()),
        BlocProvider(create: (_) => sl<PostsBloc>()),
        BlocProvider(create: (_) => sl<EnvelopeBloc>()),
        BlocProvider(create: (_) => sl<Epic11Bloc>()),
        BlocProvider(create: (_) => sl<RetryPolicyBloc>()),
        BlocProvider(create: (_) => sl<V4Bloc>()),
        BlocProvider(create: (_) => sl<TrackingBloc>()),
        BlocProvider(create: (_) => sl<SentryBloc>()),
      ],
      child: const _HomeScreenContent(),
    );
  }
}

class _HomeScreenContent extends StatefulWidget {
  const _HomeScreenContent();

  @override
  State<_HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<_HomeScreenContent> {
  String _statusMessage = 'Ready - Select a feature to test';
  CacheStrategy _selectedStrategy = CacheStrategy.networkFirst;

  ApiClientProvider get _provider => sl<ApiClientProvider>();

  @override
  void initState() {
    super.initState();
    _reportRestoredCache();
  }

  /// Shows what the on-disk cache still held at launch.
  ///
  /// This is the whole point of `FileCacheStorage`: kill the app, reopen it,
  /// and the entries are still there. With the default `InMemoryCacheStorage`
  /// this count would be 0 on every cold start.
  Future<void> _reportRestoredCache() async {
    final keys = await _provider.cacheInterceptor.getCacheKeys();
    if (!mounted) return;
    _updateStatus(
      keys.isEmpty
          ? 'Ready — no cache on disk yet. Fetch posts, then relaunch.'
          : '💾 Restored ${keys.length} cache '
                '${keys.length == 1 ? 'entry' : 'entries'} from disk',
    );
  }

  void _updateStatus(String message) {
    setState(() => _statusMessage = message);
  }

  Future<File> _createDemoFile() async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/apix_demo_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    await file.writeAsString('Hello from apix MultipartInterceptor demo.\n');
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: ApixColors.deepNavy,
                shape: BoxShape.circle,
                border: Border.all(color: ApixColors.borderBlue, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.star,
                  color: ApixColors.sparkOrange,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text('ApiX Example'),
          ],
        ),
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<UsersBloc, UsersState>(listener: _onUsersState),
          BlocListener<PostsBloc, PostsState>(listener: _onPostsState),
          BlocListener<EnvelopeBloc, EnvelopeState>(listener: _onEnvelopeState),
          BlocListener<Epic11Bloc, Epic11State>(listener: _onEpic11State),
          BlocListener<RetryPolicyBloc, RetryPolicyState>(
            listener: _onRetryPolicyState,
          ),
          BlocListener<V4Bloc, V4State>(listener: _onV4State),
          BlocListener<TrackingBloc, TrackingState>(listener: _onTrackingState),
          BlocListener<SentryBloc, SentryState>(listener: _onSentryState),
        ],
        child: Column(
          children: [
            StatusBar(
              message: _statusMessage,
              lastMetrics: _provider.lastMetrics,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection(context, 'Users (Basic Requests)', [
                    _btn(
                      'Fetch Users',
                      () => context.read<UsersBloc>().add(const FetchUsers()),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection(context, 'Cache Strategies', [
                    CacheStrategySelector(
                      selected: _selectedStrategy,
                      onChanged: (strategy) {
                        setState(() => _selectedStrategy = strategy);
                        context.read<PostsBloc>().add(
                          FetchPosts(strategy: strategy),
                        );
                      },
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _buildSection(context, 'Cache Actions', [
                    _btn(
                      'Force Refresh',
                      () => context.read<PostsBloc>().add(
                        FetchPosts(
                          strategy: _selectedStrategy,
                          forceRefresh: true,
                        ),
                      ),
                    ),
                    _btn(
                      'Clear Cache',
                      () => context.read<PostsBloc>().add(
                        const ClearPostsCache(),
                      ),
                    ),
                    _btn(
                      'Inspect Keys',
                      () => context.read<PostsBloc>().add(
                        const InspectCacheKeys(),
                      ),
                    ),
                    _btn(
                      'Invalidate /posts',
                      () => context.read<PostsBloc>().add(
                        const InvalidatePostsUrl('/posts'),
                      ),
                    ),
                    _btn(
                      'Invalidate path "/posts"',
                      () => context.read<PostsBloc>().add(
                        const InvalidatePostsPath('/posts'),
                      ),
                    ),
                    _btn(
                      'Invalidate prefix "GET:"',
                      () => context.read<PostsBloc>().add(
                        const InvalidatePostsByPrefix('GET:'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _buildSection(context, 'Mutations (POST/PUT/PATCH/DELETE)', [
                    _btn(
                      'Create Post',
                      () => context.read<PostsBloc>().add(
                        const CreateNewPost(
                          title: 'Hello from ApiX',
                          body: 'Created with Clean Architecture + BLoC',
                          userId: 1,
                        ),
                      ),
                    ),
                    _btn(
                      'Update Post #1',
                      () => context.read<PostsBloc>().add(
                        const UpdateExistingPost(
                          id: 1,
                          title: 'Replaced via PUT',
                          body: 'Body replaced with apix.put()',
                          userId: 1,
                        ),
                      ),
                    ),
                    _btn(
                      'Patch Post #1',
                      () => context.read<PostsBloc>().add(
                        const PatchExistingPost(
                          id: 1,
                          title: 'Patched via PATCH',
                        ),
                      ),
                    ),
                    _btn(
                      'Delete Post #1',
                      () => context.read<PostsBloc>().add(
                        const DeleteExistingPost(1),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _buildSection(context, 'Multipart Upload', [
                    _btn('Upload Demo File', () async {
                      try {
                        final file = await _createDemoFile();
                        if (!context.mounted) return;
                        context.read<PostsBloc>().add(UploadDemoFile(file));
                      } on PlatformException catch (e) {
                        _updateStatus('❌ Upload prep failed: ${e.message}');
                      }
                    }),
                  ]),
                  const SizedBox(height: 8),
                  _buildSection(context, 'Envelope API ({"payload": ...})', [
                    _btn(
                      'getAndDecodeData',
                      () => context.read<EnvelopeBloc>().add(
                        const FetchEnvelopeUser(7),
                      ),
                    ),
                    _btn(
                      'getListAndDecodeData',
                      () => context.read<EnvelopeBloc>().add(
                        const FetchEnvelopeUsers(),
                      ),
                    ),
                    _btn(
                      'getListAndParseData',
                      () => context.read<EnvelopeBloc>().add(
                        const FetchEnvelopeRoles(),
                      ),
                    ),
                    _btn(
                      'postAndDecodeData',
                      () => context.read<EnvelopeBloc>().add(
                        const CreateEnvelopeUser('Charlie'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _buildSection(context, '🛡️ v2.1 — Robustness', [
                    _btn(
                      'ParsingException',
                      () => context.read<Epic11Bloc>().add(
                        const TriggerParsingException(),
                      ),
                    ),
                    _btn(
                      'UnexpectedContentType',
                      () => context.read<Epic11Bloc>().add(
                        const TriggerCaptivePortal(),
                      ),
                    ),
                    _btn(
                      'responseValidator (200 → BusinessException)',
                      () => context.read<Epic11Bloc>().add(
                        const TriggerBusinessError(),
                      ),
                    ),
                    _btn(
                      'Retry-After honored',
                      () => context.read<Epic11Bloc>().add(
                        const TriggerRetryAfter(),
                      ),
                    ),
                    _btn(
                      'TokenProviderException',
                      () => context.read<Epic11Bloc>().add(
                        const TriggerTokenProviderFailure(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Every route below replies 503, so only the HTTP method
                  // (and an explicit opt-in) decides whether apix replays it.
                  _buildSection(context, '🔁 v2.3 — Method-aware retry', [
                    _btn(
                      'GET (idempotent)',
                      () => context.read<RetryPolicyBloc>().add(
                        const RunRetryProbe(RetryProbe.idempotentGet),
                      ),
                    ),
                    _btn(
                      'POST (not replayed)',
                      () => context.read<RetryPolicyBloc>().add(
                        const RunRetryProbe(RetryProbe.nonIdempotentPost),
                      ),
                    ),
                    _btn(
                      'POST + forceRetry()',
                      () => context.read<RetryPolicyBloc>().add(
                        const RunRetryProbe(RetryProbe.forcedPost),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Unlike the Sentry section below — which throws
                  // hand-made exceptions — these two travel the real
                  // interceptor chain, so they show what apix actually hands
                  // to the tracker.
                  _buildSection(context, '✨ v4.0 — What the report asked for', [
                    _btn(
                      'Error code (409)',
                      () => context.read<V4Bloc>().add(
                        const RunV4Probe(V4Probe.applicationErrorCode),
                      ),
                    ),
                    _btn(
                      'Rate limit (429)',
                      () => context.read<V4Bloc>().add(
                        const RunV4Probe(V4Probe.rateLimited),
                      ),
                    ),
                    _btn(
                      'Dedup, no cache',
                      () => context.read<V4Bloc>().add(
                        const RunV4Probe(V4Probe.deduplicationWithoutCache),
                      ),
                    ),
                    _btn(
                      'networkOnly writes nothing',
                      () => context.read<V4Bloc>().add(
                        const RunV4Probe(V4Probe.networkOnlyStoresNothing),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _buildSection(context, '📤 v3.0 — What reaches the tracker', [
                    _btn(
                      '500 → reported',
                      () => context.read<TrackingBloc>().add(
                        const RunTrackingProbe(TrackingProbe.serverError),
                      ),
                    ),
                    _btn(
                      'Connection lost → filtered',
                      () => context.read<TrackingBloc>().add(
                        const RunTrackingProbe(TrackingProbe.connectionLost),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection(context, '🐛 Sentry Integration', [
                    _sentryBtn(
                      context,
                      'Test Error (500)',
                      const TriggerTestError(),
                    ),
                    _sentryBtn(context, 'Timeout', const TriggerTimeout()),
                    _sentryBtn(
                      context,
                      'Not Found (404)',
                      const TriggerNotFound(),
                    ),
                    _sentryBtn(
                      context,
                      'Unauthorized (401)',
                      const TriggerUnauthorized(),
                    ),
                    _sentryBtn(
                      context,
                      'Real API Error',
                      const TriggerRealApiError(),
                    ),
                    _sentryBtn(
                      context,
                      'Manual Message',
                      const CaptureManualException('Test message from ApiX'),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  BlocBuilder<UsersBloc, UsersState>(
                    builder: (context, state) {
                      if (state is UsersLoaded) {
                        return UserList(users: state.users);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  BlocBuilder<PostsBloc, PostsState>(
                    builder: (context, state) {
                      if (state is PostsLoaded) {
                        return PostList(
                          posts: state.posts,
                          fromCache: state.fromCache,
                          fromCacheStale: state.fromCacheStale,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Listeners ---------------------------------------------------------

  void _onUsersState(BuildContext context, UsersState state) {
    if (state is UsersLoading) {
      _updateStatus('⏳ Fetching users...');
    } else if (state is UsersLoaded) {
      _updateStatus(
        '✅ Loaded ${state.users.length} users in '
        '${state.duration?.inMilliseconds ?? 0}ms',
      );
    } else if (state is UsersError) {
      _updateStatus('❌ Error: ${state.message}');
    }
  }

  void _onPostsState(BuildContext context, PostsState state) {
    if (state is PostsLoading) {
      _updateStatus('⏳ Fetching posts (${state.strategy.name})...');
    } else if (state is PostsLoaded) {
      _updateStatus(
        '✅ [${state.strategy.name}] ${state.posts.length} posts in '
        '${state.duration.inMilliseconds}ms'
        '${_cacheSuffix(state)}',
      );
    } else if (state is PostCreated) {
      _updateStatus('✅ Created post #${state.post.id}: ${state.post.title}');
    } else if (state is PostUpdated) {
      _updateStatus('✅ ${state.verb} #${state.post.id}: ${state.post.title}');
    } else if (state is PostDeleted) {
      _updateStatus('🗑 Deleted post #${state.id}');
    } else if (state is FileUploaded) {
      _updateStatus('📤 Uploaded ${state.filename} (${state.sizeBytes} bytes)');
    } else if (state is CacheCleared) {
      _updateStatus('🗑️ Cleared ${state.clearedCount} cache entries');
    } else if (state is CacheInvalidated) {
      _updateStatus(
        '♻️ ${state.operation} → ${state.affected} entries removed',
      );
    } else if (state is CacheKeysListed) {
      final preview = state.keys.take(3).join(' | ');
      _updateStatus(
        '🔑 ${state.keys.length} cache keys'
        '${state.keys.isEmpty ? '' : ' → $preview'}',
      );
    } else if (state is PostsError) {
      final tag = state.strategy != null ? '[${state.strategy!.name}] ' : '';
      _updateStatus('❌ ${tag}Error: ${state.message}');
    }
  }

  /// Says where the list came from — and, when it came from the cache past its
  /// TTL, that it may no longer be current.
  String _cacheSuffix(PostsLoaded state) {
    if (!state.fromCache) return '';
    return state.fromCacheStale
        ? ' (from cache — stale, refreshing)'
        : ' (from cache)';
  }

  void _onEnvelopeState(BuildContext context, EnvelopeState state) {
    if (state is EnvelopeLoading) {
      _updateStatus('⏳ ${state.operation}...');
    } else if (state is EnvelopeResult) {
      _updateStatus('✅ ${state.operation} → ${state.summary}');
    } else if (state is EnvelopeError) {
      _updateStatus('❌ ${state.operation} → ${state.message}');
    }
  }

  void _onEpic11State(BuildContext context, Epic11State state) {
    if (state is Epic11Running) {
      _updateStatus('⏳ ${state.scenario}...');
    } else if (state is Epic11Captured) {
      _updateStatus('✅ Caught ${state.exceptionType} → ${state.message}');
    } else if (state is Epic11RetryAfterSucceeded) {
      _updateStatus(
        '⏱ Retry-After honored — total ${state.elapsedMs}ms '
        '(expected ≥1000ms)',
      );
    } else if (state is Epic11Unexpected) {
      _updateStatus('⚠️ ${state.scenario}: ${state.reason}');
    }
  }

  void _onV4State(BuildContext context, V4State state) {
    if (state is V4Running) {
      _updateStatus('⏳ Running ${_v4Label(state.probe)}...');
    } else if (state is V4Measured) {
      _updateStatus(
        '✨ ${_v4Label(state.result.probe)} — '
        '${state.result.headline}',
      );
    } else if (state is V4Failed) {
      _updateStatus('❌ ${_v4Label(state.probe)} — ${state.reason}');
    }
  }

  String _v4Label(V4Probe probe) => switch (probe) {
    V4Probe.applicationErrorCode => 'application error code',
    V4Probe.rateLimited => 'rate limit',
    V4Probe.deduplicationWithoutCache => 'dedup without cache',
    V4Probe.networkOnlyStoresNothing => 'networkOnly',
  };

  void _onRetryPolicyState(BuildContext context, RetryPolicyState state) {
    if (state is RetryPolicyRunning) {
      _updateStatus('⏳ Probing retry policy (${_probeLabel(state.probe)})...');
    } else if (state is RetryPolicyMeasured) {
      final r = state.result;
      _updateStatus(
        '${r.wasRetried ? '🔁' : '🛑'} ${_probeLabel(r.probe)} — server hit '
        '${r.attempts}x '
        '(${r.wasRetried ? 'replayed' : 'not replayed'})',
      );
    } else if (state is RetryPolicyUnexpected) {
      _updateStatus('⚠️ ${_probeLabel(state.probe)}: ${state.reason}');
    }
  }

  String _probeLabel(RetryProbe probe) => switch (probe) {
    RetryProbe.idempotentGet => 'GET',
    RetryProbe.nonIdempotentPost => 'POST',
    RetryProbe.forcedPost => 'POST + forceRetry()',
  };

  void _onTrackingState(BuildContext context, TrackingState state) {
    if (state is TrackingRunning) {
      _updateStatus('⏳ Probing what the tracker receives...');
    } else if (state is TrackingMeasured) {
      final r = state.result;
      // Says both what the caller caught and what the tracker got: the 3.0.0
      // change is that these are now the same typed exception.
      _updateStatus(
        r.reachesDashboard
            ? '📤 Caught ${r.caught} → tracker got ${r.reported} → in Sentry'
            : '🔇 Caught ${r.caught} → tracker got ${r.reported} → '
                  'filtered as noise',
      );
    } else if (state is TrackingUnexpected) {
      _updateStatus('⚠️ ${state.reason}');
    }
  }

  void _onSentryState(BuildContext context, SentryState state) {
    if (state is SentryTesting) {
      _updateStatus('🔍 Testing Sentry: ${state.testName}...');
    } else if (state is SentryErrorCaptured) {
      _updateStatus(
        '🐛 Sentry captured [${state.errorType}]: ${state.message}',
      );
    } else if (state is SentryTestFailed) {
      _updateStatus('⚠️ Sentry test: ${state.reason}');
    }
  }

  // --- UI helpers --------------------------------------------------------

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            // Scheme-derived: Colors.grey.shade600 was picked against the light
            // background and disappears on the dark one.
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }

  Widget _btn(String label, VoidCallback onPressed) {
    return FilledButton.tonal(onPressed: onPressed, child: Text(label));
  }

  Widget _sentryBtn(BuildContext context, String label, SentryTestEvent event) {
    return FilledButton.tonal(
      onPressed: () => context.read<SentryBloc>().add(event),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade700,
      ),
      child: Text(label),
    );
  }
}
