import 'base_entity.dart';

class ExamEntity extends BaseEntity<int> {
  final String? code;
  final int? durationMinutes;
  final int totalQuestions;
  final bool isPublic;

  const ExamEntity({
    required int id,
    required String name, // tương ứng với `title` trong SQL
    String? description,
    this.code,
    this.durationMinutes,
    this.totalQuestions = 0,
    this.isPublic = true,
  }) : super(id: id, name: name, description: description);

  factory ExamEntity.fromJson(Map<String, dynamic> json) {
    return ExamEntity(
      id: json['id'] ?? 0,
      name: json['title'] ?? '', // Mapping từ cột `title` của SQL
      description: json['description'],
      code: json['code'],
      durationMinutes: json['duration'], // Mapping từ cột `duration` của SQL
      totalQuestions: json['total_questions'] ?? 0,
      isPublic: json['is_public'] == 1 || json['is_public'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': name,
      'description': description,
      'code': code,
      'duration': durationMinutes,
      'is_public': isPublic,
    };
  }
}