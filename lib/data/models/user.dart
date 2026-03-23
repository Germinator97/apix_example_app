import '../../domain/entities/user.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? website;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.website,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
    );
  }

  User toEntity() {
    return User(
      id: id,
      name: name,
      email: email,
      phone: phone,
      website: website,
    );
  }
}
