import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exam_model.dart';

class ExamStatsScreen extends StatelessWidget {
  final ExamModel exam;

  const ExamStatsScreen({Key? key, required this.exam}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống kê: ${exam.title}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Mã đề: ${exam.code} · ${exam.totalQuestions} câu',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Truy vấn danh sách kết quả làm bài của đề thi này
        stream: FirebaseFirestore.instance
            .collection('exam_submissions')
            .where('examId', isEqualTo: exam.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final int totalSubmissions = docs.length;

          // Tính toán số liệu thống kê
          double totalScore = 0;
          int passCount = 0; // Điểm >= 5.0 là Đạt

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final correct = (data['correctCount'] ?? 0).toDouble();
            final total = (data['totalQuestions'] ?? exam.totalQuestions)
                .toDouble();
            final double score = total == 0 ? 0 : correct / total * 10;
            totalScore += score;
            if (score >= 5.0) passCount++;
          }

          final double avgScore = totalSubmissions > 0
              ? (totalScore / totalSubmissions)
              : 0.0;
          final double passRate = totalSubmissions > 0
              ? (passCount / totalSubmissions * 100)
              : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. CARDS TỔNG QUAN CHỈ SỐ THỐNG KÊ
                // ==========================================
                Row(
                  children: [
                    _buildStatCard(
                      'Lượt làm bài',
                      '$totalSubmissions',
                      Icons.people_alt,
                      Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Điểm trung bình',
                      avgScore.toStringAsFixed(1),
                      Icons.analytics,
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard(
                      'Tỷ lệ Đạt (≥ 5d)',
                      '${passRate.toStringAsFixed(0)}%',
                      Icons.check_circle,
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Thời lượng',
                      '${exam.durationMinutes}p',
                      Icons.timer,
                      Colors.purple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ==========================================
                // 2. DANH SÁCH LƯỢT NỘP BÀI CỦA SINH VIÊN
                // ==========================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Danh sách lượt nộp bài',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$totalSubmissions lượt',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (totalSubmissions == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.assignment_late_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có sinh viên nào tham gia làm bài thi này.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final String studentName =
                          data['userName']?.toString().trim().isNotEmpty == true
                          ? data['userName'].toString()
                          : 'Sinh viên';
                      final String studentEmail =
                          data['userEmail']?.toString().trim().isNotEmpty ==
                              true
                          ? data['userEmail'].toString()
                          : 'N/A';
                      final int correctAnswers =
                          (data['correctCount'] as num?)?.toInt() ?? 0;
                      final int totalQ =
                          (data['totalQuestions'] as num?)?.toInt() ??
                          exam.totalQuestions;
                      final rawScore = data['score'];
                      final double score = rawScore is num
                          ? rawScore.toDouble()
                          : totalQ == 0
                          ? 0
                          : correctAnswers / totalQ * 10;

                      final bool isPass = score >= 5.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPass
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            child: Icon(
                              isPass ? Icons.check : Icons.close,
                              color: isPass ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '$studentEmail · $correctAnswers/$totalQ câu đúng',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isPass
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${score.toStringAsFixed(1)} điểm',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isPass
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ),
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

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
