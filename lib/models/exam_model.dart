import 'base_model.dart';

class ExamModel implements BaseModel {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool isActive;

  final String title;
  final String categoryTag; // Vd: TOÁN, ANH, LÝ
  final int totalQuestions;
  final int durationMinutes;
  final String authorName;
  final String authorId;
  final bool isPublic;
  final bool allowPractice;
  final String accessPassword;
  final String code;

  ExamModel({
    required this.id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    required this.title,
    required this.categoryTag,
    required this.totalQuestions,
    required this.durationMinutes,
    required this.authorName,
    this.authorId = '',
    required this.isPublic,
    this.allowPractice = true,
    this.accessPassword = '',
    required this.code,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // ORM: Đọc từ Firestore Map sang Object
  factory ExamModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExamModel(
      id: docId,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      title: map['title'] ?? '',
      categoryTag: map['categoryTag'] ?? 'KHÁC',
      totalQuestions: map['totalQuestions'] ?? 0,
      durationMinutes: map['durationMinutes'] ?? 0,
      authorName: map['authorName'] ?? '',
      authorId: map['authorId'] ?? '',
      isPublic: map['isPublic'] ?? true,
      allowPractice: map['allowPractice'] ?? true,
      accessPassword: map['accessPassword'] ?? '',
      code: map['code'] ?? '',
    );
  }

  // ORM: Chuyển Object sang Map để đẩy lên Firebase
  @override
  Map<String, dynamic> toMap() {
    return {
      'createdAt': createdAt,
      'updatedAt': DateTime.now(),
      'isActive': isActive,
      'title': title,
      'categoryTag': categoryTag,
      'totalQuestions': totalQuestions,
      'durationMinutes': durationMinutes,
      'authorName': authorName,
      'authorId': authorId,
      'isPublic': isPublic,
      'allowPractice': allowPractice,
      'accessPassword': accessPassword,
      'code': code,
    };
  }
}
