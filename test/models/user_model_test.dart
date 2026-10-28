import 'package:flutter_test/flutter_test.dart';
import 'package:laptrinhdidong/models/user_model.dart';

void main() {
  group('UserModel Unit Tests', () {
    test('Khởi tạo UserModel với các giá trị mặc định chính xác', () {
      final user = UserModel(
        id: 'user_001',
        fullName: 'Nguyễn Văn Lãi',
        email: 'lai@gmail.com',
        role: 'student',
      );

      expect(user.id, equals('user_001'));
      expect(user.fullName, equals('Nguyễn Văn Lãi'));
      expect(user.email, equals('lai@gmail.com'));
      expect(user.role, equals('student'));
      expect(user.streakDays, equals(0)); // Giá trị mặc định[cite: 13]
      expect(user.isActive, isTrue); // Giá trị mặc định[cite: 13]
    });

    test('fromMap ép kiểu chính xác từ Map dữ liệu Firestore', () {
      final mapData = {
        'fullName': 'Trần Văn B',
        'email': 'tranb@gmail.com',
        'role': 'teacher',
        'streakDays': 5,
        'isActive': true,
        'createdAt': '2026-05-10T08:00:00.000Z',
      };

      final user = UserModel.fromMap(mapData, 'user_002');

      expect(user.id, equals('user_002'));
      expect(user.fullName, equals('Trần Văn B'));
      expect(user.role, equals('teacher'));
      expect(user.streakDays, equals(5));
      expect(user.createdAt.year, equals(2026));
    });

    test('toMap chuyển đổi đối tượng thành Map để lưu Firestore', () {
      final user = UserModel(
        id: 'user_003',
        fullName: 'Phạm Thị C',
        email: 'phamc@gmail.com',
        role: 'student',
        streakDays: 12,
      );

      final map = user.toMap();

      expect(map['fullName'], equals('Phạm Thị C'));
      expect(map['email'], equals('phamc@gmail.com'));
      expect(map['role'], equals('student'));
      expect(map['streakDays'], equals(12));
      expect(map['isActive'], isTrue);
      expect(map['updatedAt'], isA<DateTime>());
    });
  });
}