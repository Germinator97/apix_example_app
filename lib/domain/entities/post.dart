import 'package:equatable/equatable.dart';

/// Post entity representing a post in the domain layer.
class Post extends Equatable {
  final int id;
  final int userId;
  final String title;
  final String body;

  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  @override
  List<Object?> get props => [id, userId, title, body];
}
