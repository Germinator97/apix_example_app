import 'dart:io';

import 'package:apix/apix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/di/injection_container.dart';
import '../../core/services/api_client_provider.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/envelope/envelope_bloc.dart';
import '../blocs/envelope/envelope_event.dart';
import '../blocs/envelope/envelope_state.dart';
import '../blocs/posts/posts_bloc.dart';
import '../blocs/posts/posts_event.dart';
import '../blocs/posts/posts_state.dart';
import '../../core/probes/demo_probe.dart';
import '../../core/probes/probe_registry.dart';
import '../blocs/probes/probe_bloc.dart';
import '../blocs/sentry/sentry_bloc.dart';
import '../blocs/sentry/sentry_event.dart';
import '../blocs/sentry/sentry_state.dart';
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
        BlocProvider(create: (_) => sl<ProbeBloc>()),
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
          BlocListener<ProbeBloc, ProbeState>(listener: _onProbeState),
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
                  ..._themeSections(context),
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

  /// The hand-written parts of a theme: live features, not probes.
  ///
  /// Probes are self-contained and come from the registry. These drive the app
  /// itself — they own blocs that hold lists and render into widgets rather
  /// than a status line — so they stay hand-written. Filing them under the same
  /// themes is what makes the screen read as one taxonomy: "Cache Actions" and
  /// "the cache is scoped to the caller" belong together, and used to sit in
  /// different halves of the same page.
  List<Widget> _featureWidgets(BuildContext context, ProbeTheme theme) {
    switch (theme) {
      case ProbeTheme.requests:
        return [
          _btn(
            'Fetch Users',
            () => context.read<UsersBloc>().add(const FetchUsers()),
          ),
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
              const PatchExistingPost(id: 1, title: 'Patched via PATCH'),
            ),
          ),
          _btn(
            'Delete Post #1',
            () => context.read<PostsBloc>().add(const DeleteExistingPost(1)),
          ),
          _btn(
            'getAndDecodeData',
            () => context.read<EnvelopeBloc>().add(const FetchEnvelopeUser(7)),
          ),
          _btn(
            'getListAndDecodeData',
            () => context.read<EnvelopeBloc>().add(const FetchEnvelopeUsers()),
          ),
          _btn(
            'getListAndParseData',
            () => context.read<EnvelopeBloc>().add(const FetchEnvelopeRoles()),
          ),
          _btn(
            'postAndDecodeData',
            () => context.read<EnvelopeBloc>().add(
              const CreateEnvelopeUser('Charlie'),
            ),
          ),
        ];
      case ProbeTheme.cache:
        return [
          CacheStrategySelector(
            selected: _selectedStrategy,
            onChanged: (strategy) {
              setState(() => _selectedStrategy = strategy);
              context.read<PostsBloc>().add(FetchPosts(strategy: strategy));
            },
          ),
          _btn(
            'Force Refresh',
            () => context.read<PostsBloc>().add(
              FetchPosts(strategy: _selectedStrategy, forceRefresh: true),
            ),
          ),
          _btn(
            'Clear Cache',
            () => context.read<PostsBloc>().add(const ClearPostsCache()),
          ),
          _btn(
            'Inspect Keys',
            () => context.read<PostsBloc>().add(const InspectCacheKeys()),
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
        ];
      case ProbeTheme.authUploads:
        return [
          _btn('Upload Demo File', () async {
            try {
              final file = await _createDemoFile();
              if (!context.mounted) return;
              context.read<PostsBloc>().add(UploadDemoFile(file));
            } on PlatformException catch (e) {
              _updateStatus('❌ Upload prep failed: ${e.message}');
            }
          }),
        ];
      case ProbeTheme.observability:
        return [
          _sentryBtn(context, 'Test Error (500)', const TriggerTestError()),
          _sentryBtn(context, 'Timeout', const TriggerTimeout()),
          _sentryBtn(context, 'Not Found (404)', const TriggerNotFound()),
          _sentryBtn(
            context,
            'Unauthorized (401)',
            const TriggerUnauthorized(),
          ),
          _sentryBtn(context, 'Real API Error', const TriggerRealApiError()),
          _sentryBtn(
            context,
            'Manual Message',
            const CaptureManualException('Test message from ApiX'),
          ),
        ];
      case ProbeTheme.errors:
      case ProbeTheme.retry:
        return const [];
    }
  }

  /// One section per theme, features first, then the probes that pin them.
  ///
  /// A theme with neither renders nothing, so the list of themes can grow
  /// without leaving empty headings behind.
  List<Widget> _themeSections(BuildContext context) {
    final registry = sl<ProbeRegistry>();
    final sections = <Widget>[];

    for (final theme in ProbeTheme.values) {
      final children = <Widget>[
        ..._featureWidgets(context, theme),
        for (final probe in registry.byTheme(theme))
          _btn(
            probe.label,
            () => context.read<ProbeBloc>().add(RunProbe(probe)),
          ),
      ];
      if (children.isEmpty) continue;
      sections
        ..add(_buildSection(context, theme.heading, children))
        ..add(const SizedBox(height: 8));
    }

    return sections;
  }

  void _onProbeState(BuildContext context, ProbeState state) {
    if (state is ProbeRunning) {
      _updateStatus('⏳ ${state.probe.label}...');
    } else if (state is ProbeMeasured) {
      _updateStatus(
        '${state.probe.theme.icon} ${state.probe.label} — '
        '${state.outcome.headline}',
      );
    } else if (state is ProbeFailed) {
      _updateStatus('❌ ${state.probe.label} — ${state.reason}');
    }
  }

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
