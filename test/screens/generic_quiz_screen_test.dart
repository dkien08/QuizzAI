import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laptrinhdidong/screens/generic_quiz_screen.dart';

void main() {
  final mockQuestions = [
    {
      'content': 'Thủ đô của Việt Nam là gì?',
      'options': ['Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Hải Phòng'],
      'correctAnswerIndex': 1,
    },
    {
      'content': 'Flutter được phát triển bởi công ty nào?',
      'options': ['Facebook', 'Apple', 'Google', 'Microsoft'],
      'correctAnswerIndex': 2,
    }
  ];

  group('GenericQuizScreen Widget Tests', () {
    testWidgets('Hiển thị thông báo khi đề thi không có câu hỏi', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: GenericQuizScreen(
            examTitle: 'Đề thi rỗng',
            durationMinutes: 15,
            questions: [],
          ),
        ),
      );

      expect(find.text('Đề thi "Đề thi rỗng" chưa có câu hỏi.'), findsOneWidget);
      expect(find.text('Quay lại'), findsOneWidget);
    });

    testWidgets('Hiển thị nội dung câu hỏi và các đáp án ở chế độ Luyện tập', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenericQuizScreen(
            examTitle: 'Luyện tập Flutter',
            durationMinutes: 0,
            isPracticeMode: true,
            questions: mockQuestions,
          ),
        ),
      );

      // Kiểm tra tiêu đề màn hình và số thứ tự câu hỏi
      expect(find.text('Luyện tập Flutter'), findsOneWidget);
      expect(find.text('Thủ đô của Việt Nam là gì?'), findsOneWidget);

      // Kiểm tra hiển thị các lựa chọn
      expect(find.text('Hồ Chí Minh'), findsOneWidget);
      expect(find.text('Hà Nội'), findsOneWidget);
      expect(find.text('Đà Nẵng'), findsOneWidget);
      expect(find.text('Hải Phòng'), findsOneWidget);
    });

    testWidgets('Chọn đúng đáp án hiển thị phản hồi chính xác', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GenericQuizScreen(
            examTitle: 'Luyện tập Flutter',
            durationMinutes: 0,
            isPracticeMode: true,
            questions: mockQuestions,
          ),
        ),
      );

      // Chọn đáp án "Hà Nội" (Đáp án đúng)
      await tester.tap(find.text('Hà Nội'));
      await tester.pump();

      // Kiểm tra thông báo kết quả trả về
      expect(find.text('Chính xác! Câu này đã được hoàn thành.'), findsOneWidget);
    });
  });
}