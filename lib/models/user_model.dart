import 'base_model.dart';

class UserModel implements BaseModel {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool isActive;

  final String fullName;
  final String email;
  final String role;
  final int streakDays;

  UserModel({
    required this.id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    required this.fullName,
    required this.email,
    required this.role,
    this.streakDays = 0,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      id: docId,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      streakDays: map['streakDays'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'createdAt': createdAt,
      'updatedAt': DateTime.now(), // Tự động cập nhật thời gian sửa đổi
      'isActive': isActive,
      'fullName': fullName,
      'email': email,
      'role': role,
      'streakDays': streakDays,
    };
  }
}
