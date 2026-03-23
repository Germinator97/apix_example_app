import '../../domain/entities/post.dart';

class PostModel {
  final int id;
  final int userId;
  final String title;
  final String body;

  const PostModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  Post toEntity() {
    return Post(id: id, userId: userId, title: title, body: body);
  }
}
