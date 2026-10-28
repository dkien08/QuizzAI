import 'package:flutter_test/flutter_test.dart';

// Helper khớp 100% với hàm _parseCorrectIndex trong excel_service.dart của bạn
int parseCorrectIndex(dynamic value) {
  final answer = value?.toString().trim().toUpperCase() ?? '';
  const labels = {'A': 0, 'B': 1, 'C': 2, 'D': 3};
  if (labels.containsKey(answer)) return labels[answer]!;

  final numericAnswer = int.tryParse(answer);
  if (numericAnswer == null) return -1;
  if (numericAnswer >= 1 && numericAnswer <= 4) return numericAnswer - 1;
  return numericAnswer;
}

void main() {
  group('ExcelService Unit Tests', () {
    test('Hàm parseCorrectIndex chuyển đổi ký tự A, B, C, D sang index tương ứng', () {
      expect(parseCorrectIndex('A'), equals(0));
      expect(parseCorrectIndex('b'), equals(1));
      expect(parseCorrectIndex(' C '), equals(2));
      expect(parseCorrectIndex('D'), equals(3));
    });

    test('Hàm parseCorrectIndex chuyển đổi số 1, 2, 3, 4 sang index cơ số 0', () {
      expect(parseCorrectIndex(1), equals(0));
      expect(parseCorrectIndex('2'), equals(1));
      expect(parseCorrectIndex(3), equals(2));
      expect(parseCorrectIndex('4'), equals(3));
    });

    test('Hàm parseCorrectIndex trả về -1 cho ký tự hoặc giá trị null không hợp lệ', () {
      expect(parseCorrectIndex('E'), equals(-1));
      expect(parseCorrectIndex(null), equals(-1));
      expect(parseCorrectIndex(''), equals(-1));
    });

    test('Mô phỏng bóc tách hàng dữ liệu Excel thành Map câu hỏi', () {
      final mockRowData = [
        'Flutter là gì?',
        'Một Framework',
        'Một ngôn ngữ',
        'Một hệ điều hành',
        'Một database',
        'A'
      ];

      final questionText = mockRowData[0].trim();
      final optA = mockRowData[1].trim();
      final optB = mockRowData[2].trim();
      final optC = mockRowData[3].trim();
      final optD = mockRowData[4].trim();
      final correctIndex = parseCorrectIndex(mockRowData[5]);

      final questionMap = {
        'content': questionText,
        'options': [optA, optB, optC, optD],
        'correctAnswerIndex': correctIndex,
      };

      expect(questionMap['content'], equals('Flutter là gì?'));
      expect(questionMap['options'], contains('Một Framework'));
      expect(questionMap['correctAnswerIndex'], equals(0));
    });
  });
}