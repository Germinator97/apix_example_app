import 'package:apix/apix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection_container.dart';
import '../../core/theme/app_theme.dart';
import '../blocs/posts/posts_bloc.dart';
import '../blocs/posts/posts_event.dart';
import '../blocs/posts/posts_state.dart';
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

  void _updateStatus(String message) {
    setState(() => _statusMessage = message);
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
          BlocListener<UsersBloc, UsersState>(
            listener: (context, state) {
              if (state is UsersLoading) {
                _updateStatus('⏳ Fetching users...');
              } else if (state is UsersLoaded) {
                _updateStatus(
                  '✅ Loaded ${state.users.length} users in ${state.duration?.inMilliseconds ?? 0}ms',
                );
              } else if (state is UsersError) {
                _updateStatus('❌ Error: ${state.message}');
              }
            },
          ),
          BlocListener<SentryBloc, SentryState>(
            listener: (context, state) {
              if (state is SentryTesting) {
                _updateStatus('🔍 Testing Sentry: ${state.testName}...');
              } else if (state is SentryErrorCaptured) {
                _updateStatus(
                  '🐛 Sentry captured [${state.errorType}]: ${state.message}',
                );
              } else if (state is SentryTestFailed) {
                _updateStatus('⚠️ Sentry test: ${state.reason}');
              }
            },
          ),
          BlocListener<PostsBloc, PostsState>(
            listener: (context, state) {
              if (state is PostsLoading) {
                _updateStatus('⏳ Fetching posts (${state.strategy.name})...');
              } else if (state is PostsLoaded) {
                _updateStatus(
                  '✅ [${state.strategy.name}] ${state.posts.length} posts in ${state.duration.inMilliseconds}ms',
                );
              } else if (state is PostCreated) {
                _updateStatus(
                  '✅ Created post #${state.post.id}: ${state.post.title}',
                );
              } else if (state is CacheCleared) {
                _updateStatus(
                  '🗑️ Cleared ${state.clearedCount} cache entries',
                );
              } else if (state is PostsError) {
                final strategyInfo = state.strategy != null
                    ? '[${state.strategy!.name}] '
                    : '';
                _updateStatus('❌ ${strategyInfo}Error: ${state.message}');
              }
            },
          ),
        ],
        child: Column(
          children: [
            StatusBar(message: _statusMessage),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection(context, 'Users (Basic Requests)', [
                    _buildButton(
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
                    _buildButton(
                      'Force Refresh',
                      () => context.read<PostsBloc>().add(
                        FetchPosts(
                          strategy: _selectedStrategy,
                          forceRefresh: true,
                        ),
                      ),
                    ),
                    _buildButton(
                      'Clear Cache',
                      () => context.read<PostsBloc>().add(
                        const ClearPostsCache(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _buildSection(context, 'Mutations', [
                    _buildButton(
                      'Create Post',
                      () => context.read<PostsBloc>().add(
                        const CreateNewPost(
                          title: 'Hello from ApiX',
                          body: 'Created with Clean Architecture + BLoC',
                          userId: 1,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection(context, '🐛 Sentry Integration', [
                    _buildSentryButton(
                      context,
                      'Test Error (500)',
                      const TriggerTestError(),
                    ),
                    _buildSentryButton(
                      context,
                      'Timeout',
                      const TriggerTimeout(),
                    ),
                    _buildSentryButton(
                      context,
                      'Not Found (404)',
                      const TriggerNotFound(),
                    ),
                    _buildSentryButton(
                      context,
                      'Unauthorized (401)',
                      const TriggerUnauthorized(),
                    ),
                    _buildSentryButton(
                      context,
                      'Real API Error',
                      const TriggerRealApiError(),
                    ),
                    _buildSentryButton(
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
                        return PostList(posts: state.posts);
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
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return FilledButton.tonal(onPressed: onPressed, child: Text(label));
  }

  Widget _buildSentryButton(
    BuildContext context,
    String label,
    SentryTestEvent event,
  ) {
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
