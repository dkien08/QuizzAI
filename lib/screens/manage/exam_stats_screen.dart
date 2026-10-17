import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class ExamStatsScreen extends StatefulWidget {
  final Map<String, dynamic> examInfo;
  const ExamStatsScreen({super.key, required this.examInfo});

  @override
  State<ExamStatsScreen> createState() => _ExamStatsScreenState();
}

class _ExamStatsScreenState extends State<ExamStatsScreen> {
  static const String baseUrl = 'https://quizzapp-kovj.onrender.com';
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _fetchStats();
  }

  Future<Map<String, dynamic>> _fetchStats() async {
    final token = await AuthService.getToken();
    final examId = widget.examInfo['id'];
    final res = await http.get(
      Uri.parse('$baseUrl/exams/$examId/stats'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Không thể tải dữ liệu thống kê');
    }
  }

  @override
  Widget build(BuildContext context) {
    final examTitle = widget.examInfo['title'] ?? 'Thống kê đề thi';
    final examCode = widget.examInfo['code'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thống kê đề thi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
            ),
            Text(
              'Mã: $examCode · $examTitle',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          final data = snapshot.data ?? {};
          final totalAttempts = data['total_attempts'] ?? 0;
          final statsList = data['stats'] as List<dynamic>? ?? [];

          // Tính điểm trung bình
          double avgScore = 0.0;
          if (statsList.isNotEmpty) {
            final totalScore = statsList.fold<double>(
              0.0,
              (sum, item) => sum + (double.tryParse(item['score'].toString()) ?? 0.0),
            );
            avgScore = totalScore / statsList.length;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2 Thẻ tổng quát: Tổng lượt nộp & Điểm trung bình
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.people_alt_outlined, color: Color(0xFF2563EB), size: 28),
                            const SizedBox(height: 10),
                            Text(
                              '$totalAttempts',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            const Text('Tổng số lượt làm bài', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.analytics_outlined, color: Color(0xFF10B981), size: 28),
                            const SizedBox(height: 10),
                            Text(
                              avgScore.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            const Text('Điểm trung bình', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Danh sách thí sinh nộp bài
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Danh sách thí sinh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${statsList.length} kết quả', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),

                if (statsList.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Text('Chưa có thí sinh nào nộp bài thi này', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: statsList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = statsList[index];
                      final fullName = item['full_name'] ?? 'Ẩn danh';
                      final username = item['username'] ?? 'user';
                      final score = item['score'] != null ? item['score'].toString() : '0.0';
                      final correctCount = item['correct_count'] ?? 0;
                      final totalQuestions = item['total_questions'] ?? 0;
                      final submittedAt = item['submitted_at'] != null
                          ? item['submitted_at'].toString().split('T').first
                          : '';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            // Số thứ tự
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 14),
                            // Thông tin thí sinh
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text('@$username · Ngày nộp: $submittedAt', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text('Đúng: $correctCount/$totalQuestions câu', style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                                ],
                              ),
                            ),
                            // Điểm số nổi bật
                            Text(
                              score,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}