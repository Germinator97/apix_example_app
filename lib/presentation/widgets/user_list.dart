import 'package:flutter/material.dart';

import '../../domain/entities/user.dart';

class UserList extends StatelessWidget {
  final List<User> users;

  const UserList({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Users (${users.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...users
            .take(5)
            .map(
              (user) => ListTile(
                leading: CircleAvatar(child: Text('${user.id}')),
                title: Text(user.name),
                subtitle: Text(user.email),
                dense: true,
              ),
            ),
        if (users.length > 5)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              '... and ${users.length - 5} more',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
