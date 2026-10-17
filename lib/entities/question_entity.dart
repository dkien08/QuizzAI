import 'base_entity.dart';

class QuestionEntity extends BaseEntity<int> {
  final String? imageUrl;
  final String? aiExplanation;

  const QuestionEntity({
    required int id,
    required String name, // tương ứng `question_text` trong SQL
    this.imageUrl,
    this.aiExplanation,
  }) : super(id: id, name: name);

  factory QuestionEntity.fromJson(Map<String, dynamic> json) {
    return QuestionEntity(
      id: json['id'] ?? 0,
      name: json['question_text'] ?? '', // Mapping từ `question_text`
      imageUrl: json['image_url'],
      aiExplanation: json['ai_explanation'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': name,
      'image_url': imageUrl,
      'ai_explanation': aiExplanation,
    };
  }
}