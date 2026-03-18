import 'package:flutter/material.dart';

import '../../domain/entities/post.dart';

class PostList extends StatelessWidget {
  final List<Post> posts;

  const PostList({super.key, required this.posts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Posts (${posts.length})',
          style: Theme.of(context).textTheme.titleMedium,
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
