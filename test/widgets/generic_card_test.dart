import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laptrinhdidong/models/exam_model.dart';
import 'package:laptrinhdidong/widgets/generic_card.dart';

void main() {
  final mockExam = ExamModel(
    id: 'exam_001',
    title: 'Đề thi Lập trình Di động',
    categoryTag: 'FLUTTER',
    totalQuestions: 40,
    durationMinutes: 60,
    authorName: 'Thầy A',
    isPublic: true,
    code: 'EXAM2026',
  );

  group('GenericCard Widget Tests', () {
    testWidgets('Hiển thị chính xác tiêu đề, phụ đề, mã đề và tag PUBLIC', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericCard<ExamModel>(
              data: mockExam,
              getTag: (exam) => exam.categoryTag,
              getTitle: (exam) => exam.title,
              getSubtitle: (exam) => '${exam.totalQuestions} câu • ${exam.durationMinutes} phút',
              getCode: (exam) => exam.code,
              getIsPublic: (exam) => exam.isPublic,
              onTap: () {},
              actionLabel: 'Làm bài ngay',
            ),
          ),
        ),
      );

      // Kiểm tra văn bản hiển thị
      expect(find.text('PUBLIC'), findsOneWidget);
      expect(find.text('Đề thi Lập trình Di động'), findsOneWidget);
      expect(find.text('40 câu • 60 phút'), findsOneWidget);
      expect(find.text('Mã: EXAM2026'), findsOneWidget);
      expect(find.text('Làm bài ngay'), findsOneWidget);
    });

    testWidgets('Kích hoạt sự kiện onTap khi bấm nút hành động', (WidgetTester tester) async {
      bool isTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericCard<ExamModel>(
              data: mockExam,
              getTag: (exam) => exam.categoryTag,
              getTitle: (exam) => exam.title,
              getSubtitle: (exam) => '${exam.durationMinutes} phút',
              onTap: () {
                isTapped = true;
              },
              actionLabel: 'Bắt đầu',
            ),
          ),
        ),
      );

      // Nhấn vào nút 'Bắt đầu'
      await tester.tap(find.text('Bắt đầu'));
      await tester.pump();

      expect(isTapped, isTrue);
    });
  });
}