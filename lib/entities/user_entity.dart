import 'base_entity.dart';

class UserEntity extends BaseEntity<int> {
  final String username;
  final String role;

  const UserEntity({
    required int id,
    required String name, // tương ứng `full_name` trong SQL
    required this.username,
    required this.role,
  }) : super(id: id, name: name);

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] ?? 0,
      name: json['full_name'] ?? json['username'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? 'users',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'username': username,
      'role': role,
    };
  }
}