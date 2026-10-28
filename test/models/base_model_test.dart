import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laptrinhdidong/models/base_model.dart';

void main() {
  group('parseDateTime Helper Tests', () {
    test('Parse từ Firebase Timestamp chính xác', () {
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);

      final result = parseDateTime(timestamp);

      expect(result.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
    });

    test('Parse từ chuỗi ISO String chính xác', () {
      const dateString = '2026-10-27T10:00:00.000Z';
      final result = parseDateTime(dateString);

      expect(result.year, equals(2026));
      expect(result.month, equals(10));
      expect(result.day, equals(27));
    });

    test('Parse từ kiểu int (milliseconds epoch) chính xác', () {
      final epochMs = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final result = parseDateTime(epochMs);

      expect(result.year, equals(2026));
      expect(result.month, equals(1));
    });

    test('Trả về DateTime.now() khi truyền giá trị null hoặc không hợp lệ', () {
      final resultNull = parseDateTime(null);
      final resultInvalid = parseDateTime('invalid-date-string');

      expect(resultNull, isA<DateTime>());
      expect(resultInvalid, isA<DateTime>());
    });
  });
}