import 'package:flutter/material.dart';
import 'models/exam.dart';
import 'api_service.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ExamListScreen(),
  ));
}

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  late Future<List<dynamic>> _examsFuture;

  @override
  void initState() {
    super.initState();
    _examsFuture = ApiService.getExams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Quiz - Danh sách đề thi'),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _examsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Lỗi kết nối: ${snapshot.error}'),
            );
          }
          final rawList = snapshot.data ?? [];
          if (rawList.isEmpty) {
            return const Center(child: Text('Chưa có đề thi nào trong hệ thống'));
          }

          final exams = rawList.map((e) => Exam.fromJson(e)).toList();

          return ListView.builder(
            itemCount: exams.length,
            itemBuilder: (context, index) {
              final exam = exams[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.quiz, color: Colors.blueAccent),
                  title: Text(exam.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${exam.description ?? "Không có mô tả"} • ${exam.duration} phút'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Chọn đề thi: ${exam.title}')),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}