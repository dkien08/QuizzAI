import 'package:flutter/material.dart';
import '../../entities/base_entity.dart';
import '../base_layout_screen.dart';
import '../../entities/exam_entity.dart';

// Màn hình Quản lý Đề thi kế thừa BaseLayoutScreen với Generic T = List<ExamEntity>
class ManageExamsScreen extends BaseLayoutScreen<List<ExamEntity>> {
  final Function(ExamEntity exam) onExamSelected;

  const ManageExamsScreen({
    super.key,
    required super.title,
    super.isLoading,
    super.errorMessage,
    super.data,
    super.onRefresh,
    super.actions,
    required this.onExamSelected,
  });

  @override
  Widget buildBody(BuildContext context, List<ExamEntity>? data) {
    if (data == null || data.isEmpty) {
      return const Center(child: Text('Hiện chưa có đề thi nào'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (context, index) {
        final exam = data[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.quiz, color: Colors.white),
            ),
            title: Text(exam.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Thời lượng: ${exam.durationMinutes} phút | Câu hỏi: ${exam.totalQuestions}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => onExamSelected(exam),
          ),
        );
      },
    );
  }
}