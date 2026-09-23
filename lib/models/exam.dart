class Exam {
  final int id;
  final String? code;
  final String title;
  final String? description;
  final int duration;
  final bool isPublic;

  Exam({
    required this.id,
    this.code,
    required this.title,
    this.description,
    required this.duration,
    required this.isPublic,
  });

  // Chuyển dữ liệu JSON từ API NestJS trả về thành Object Dart
  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'],
      code: json['code'],
      title: json['title'] ?? '',
      description: json['description'],
      duration: json['duration'] ?? 0,
      isPublic: json['is_public'] == 1 || json['is_public'] == true,
    );
  }
}