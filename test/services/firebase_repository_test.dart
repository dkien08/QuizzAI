import 'package:flutter_test/flutter_test.dart';
import 'package:laptrinhdidong/models/base_model.dart';

// Tạo class MockModel kế thừa BaseModel chuẩn đủ các thuộc tính để phục vụ testing
class TestModel implements BaseModel {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool isActive;

  final String name;

  TestModel({
    required this.id,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isActive = true,
    required this.name,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
      'name': name,
    };
  }

  factory TestModel.fromMap(Map<String, dynamic> map, String id) {
    return TestModel(
      id: id,
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
      isActive: map['isActive'] ?? true,
      name: map['name'] ?? '',
    );
  }
}

void main() {
  group('FirebaseRepository Model Mapping Tests', () {
    test('Chuyển đổi dữ liệu từ Map sang BaseModel chính xác', () {
      final docData = {'name': 'Bài thi mẫu', 'isActive': true};
      const docId = 'doc_123';

      final model = TestModel.fromMap(docData, docId);

      expect(model.id, equals('doc_123'));
      expect(model.name, equals('Bài thi mẫu'));
      expect(model.isActive, isTrue);
    });

    test('Chuyển đổi từ BaseModel sang Map để lưu lên Firestore', () {
      final model = TestModel(id: 'doc_456', name: 'Luyện tập Flutter');
      final mapData = model.toMap();

      expect(mapData['id'], equals('doc_456'));
      expect(mapData['name'], equals('Luyện tập Flutter'));
      expect(mapData['isActive'], isTrue);
    });
  });
}