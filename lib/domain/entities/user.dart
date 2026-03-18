import 'package:equatable/equatable.dart';

/// User entity representing a user in the domain layer.
class User extends Equatable {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? website;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.website,
  });

  @override
  List<Object?> get props => [id, name, email, phone, website];
}
