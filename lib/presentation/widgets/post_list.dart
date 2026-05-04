import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/post.dart';

class PostList extends StatelessWidget {
  final List<Post> posts;
  final bool fromCache;

  const PostList({super.key, required this.posts, this.fromCache = false});

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
            if (fromCache)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ApixColors.sparkOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ApixColors.sparkOrange.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text(
                  'from cache',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ApixColors.sparkOrange,
                  ),
                ),
              ),
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
