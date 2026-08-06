import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/post.dart';

class PostList extends StatelessWidget {
  final List<Post> posts;
  final bool fromCache;

  /// Whether the cached body shown was past its TTL (apix `response.isStale`).
  ///
  /// Distinguished from [fromCache] on purpose: since apix 3.0.0 a cached
  /// response can legitimately be expired — `cacheFirst` revalidating behind,
  /// or an offline fallback — and "from cache" alone would let the user
  /// believe the figures are current.
  final bool fromCacheStale;

  const PostList({
    super.key,
    required this.posts,
    this.fromCache = false,
    this.fromCacheStale = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Posts (${posts.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            if (fromCache) _CacheBadge(stale: fromCacheStale),
          ],
        ),
        const SizedBox(height: 8),
        ...posts
            .take(5)
            .map(
              (post) => ListTile(
                leading: CircleAvatar(child: Text('${post.id}')),
                title: Text(
                  post.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  post.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                dense: true,
              ),
            ),
        if (posts.length > 5)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              '... and ${posts.length - 5} more',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// Badge telling where the list came from, and whether it is still current.
class _CacheBadge extends StatelessWidget {
  const _CacheBadge({required this.stale});

  final bool stale;

  @override
  Widget build(BuildContext context) {
    // Deliberately different wording, not just a different colour: "from
    // cache" says where the data came from, "from earlier" says it may be
    // wrong. Only the second one changes what the user should do with it.
    final colour = stale ? Colors.orange.shade800 : ApixColors.sparkOrange;
    final label = stale ? 'from earlier — refreshing' : 'from cache';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colour,
        ),
      ),
    );
  }
}
