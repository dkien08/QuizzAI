import 'package:flutter_test/flutter_test.dart';
import 'package:laptrinhdidong/models/exam_model.dart';

void main() {
  group('ExamModel Unit Tests', () {
    test('Khởi tạo ExamModel đúng với dữ liệu bắt buộc', () {
      final exam = ExamModel(
        id: 'exam_001',
        title: 'Đề thi Lập trình Di động',
        categoryTag: 'FLUTTER',
        totalQuestions: 40,
        durationMinutes: 60,
        authorName: 'Giảng viên A',
        isPublic: true,
        code: 'EXAM123',
      );

      expect(exam.id, equals('exam_001'));
      expect(exam.title, equals('Đề thi Lập trình Di động'));
      expect(exam.categoryTag, equals('FLUTTER'));
      expect(exam.totalQuestions, equals(40));
      expect(exam.durationMinutes, equals(60));
      expect(exam.code, equals('EXAM123'));
      expect(exam.accessPassword, equals('')); // Mặc định rỗng[cite: 12]
    });

    test('fromMap đọc đúng thông tin từ Firestore Map', () {
      final mapData = {
        'title': 'Đề thi An toàn Thông tin',
        'categoryTag': 'BAO_MAT',
        'totalQuestions': 25,
        'durationMinutes': 30,
        'authorName': 'Thầy B',
        'isPublic': false,
        'accessPassword': 'pass123',
        'code': 'ATTT2026',
      };

      final exam = ExamModel.fromMap(mapData, 'exam_002');

      expect(exam.id, equals('exam_002'));
      expect(exam.title, equals('Đề thi An toàn Thông tin'));
      expect(exam.isPublic, isFalse);
      expect(exam.accessPassword, equals('pass123'));
    });

    test('toMap tạo đúng Map dữ liệu đẩy lên Firestore', () {
      final exam = ExamModel(
        id: 'exam_003',
        title: 'Trắc nghiệm Dart',
        categoryTag: 'DART',
        totalQuestions: 20,
        durationMinutes: 15,
        authorName: 'Admin',
        isPublic: true,
        code: 'DART01',
      );

      final map = exam.toMap();

      expect(map['title'], equals('Trắc nghiệm Dart'));
      expect(map['categoryTag'], equals('DART'));
      expect(map['totalQuestions'], equals(20));
      expect(map['durationMinutes'], equals(15));
      expect(map['code'], equals('DART01'));
      expect(map['updatedAt'], isA<DateTime>());
    });
  });
}