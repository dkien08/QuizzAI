import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ExamScreen extends StatefulWidget {
  final Map<String, dynamic> examData;

  const ExamScreen({super.key, required this.examData});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  static const String baseUrl = 'https://quizzapp-kovj.onrender.com';

  late int _remainingSeconds;
  Timer? _timer;
  int _currentIndex = 0;
  bool _isSubmitting = false;

  // Lưu đáp án thí sinh đã chọn: { question_id: option_id }
  final Map<int, int> _selectedAnswers = {};

  List<dynamic> get _questions => widget.examData['questions'] ?? [];
  Map<String, dynamic> get _examInfo => widget.examData['exam'] ?? widget.examData;

  @override
  void initState() {
    super.initState();
    // Khởi tạo thời gian làm bài (đơn vị: phút -> giây)
    final durationMinutes = _examInfo['duration'] ?? 30;
    _remainingSeconds = durationMinutes * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        _autoSubmitOnTimeUp();
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _autoSubmitOnTimeUp() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Hết giờ làm bài!'),
          ],
        ),
        content: const Text('Thời gian làm bài đã kết thúc. Hệ thống sẽ tự động nộp bài của bạn.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitExam();
            },
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }

  // Popup xác nhận nộp bài (Phân biệt làm hết và chưa hết câu)
  void _showSubmitConfirmationDialog() {
    final totalQuestions = _questions.length;
    final answeredCount = _selectedAnswers.length;
    final isCompleted = answeredCount == totalQuestions;
    final unansweredCount = totalQuestions - answeredCount;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                isCompleted ? 'Nộp bài thi' : 'Cảnh báo nộp bài',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompleted) ...[
                const Text(
                  'Bạn đã trả lời đầy đủ tất cả các câu hỏi.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thời gian còn lại: ${_formatDuration(_remainingSeconds)}. Bạn có chắc chắn muốn nộp bài sớm không?',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
              ] else ...[
                Text(
                  'Bạn còn $unansweredCount câu chưa hoàn thành!',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tiến độ hiện tại: $answeredCount/$totalQuestions câu.\nCác câu chưa làm sẽ không được tính điểm. Bạn vẫn muốn nộp bài chứ?',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Tiếp tục làm'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitExam();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Xác nhận nộp'),
            ),
          ],
        );
      },
    );
  }

  // Gọi API nộp bài: POST /exams/submit
  Future<void> _submitExam() async {
    setState(() => _isSubmitting = true);
    _timer?.cancel();

    final examId = _examInfo['id'];
    final formattedAnswers = _selectedAnswers.entries.map((entry) {
      return {
        'question_id': entry.key,
        'option_id': entry.value,
      };
    }).toList();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/exams/submit'),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer <token>', // Gắn token khi đăng nhập
        },
        body: jsonEncode({
          'exam_id': examId,
          'answers': formattedAnswers,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        // Chuyển sang màn hình hiển thị điểm tổng kết (GET /exams/result/:id)
        Navigator.pushReplacementNamed(
          context,
          '/exam/result',
          arguments: result,
        );
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['message'] ?? 'Nộp bài thất bại')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối khi nộp bài thi')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Làm bài thi')),
        body: const Center(child: Text('Đề thi này không có câu hỏi nào.')),
      );
    }

    final currentQuestion = _questions[_currentIndex];
    final questionId = currentQuestion['id'];
    final questionText = currentQuestion['question_text'] ?? '';
    final options = currentQuestion['options'] as List<dynamic>? ?? [];
    final totalQuestions = _questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar: Thoát - Đồng hồ đếm ngược - Nút nộp bài
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('Thoát phòng thi?'),
                          content: const Text('Bài thi của bạn sẽ không được lưu nếu bạn rời khỏi lúc này.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Ở lại')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.pop(context);
                              },
                              child: const Text('Thoát'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                    label: const Text('Thoát', style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
                  ),
                  // Bộ đếm ngược thời gian nổi bật
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alarm, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(_remainingSeconds),
                          style: const TextStyle(
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _showSubmitConfirmationDialog,
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text(
                            'Nộp bài',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // 2. Thông tin tiêu đề & Tiến độ câu hỏi
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _examInfo['title'] ?? 'Đề thi trắc nghiệm',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Đã làm ${_selectedAnswers.length}/$totalQuestions câu',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Thanh Linear Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalQuestions > 0 ? (_selectedAnswers.length / totalQuestions) : 0,
                      backgroundColor: const Color(0xFFE2E8F0),
                      color: const Color(0xFF2563EB),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Question Card & Danh sách lựa chọn A, B, C, D
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge CÂU X
                      Text(
                        'CÂU ${_currentIndex + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Nội dung câu hỏi
                      Text(
                        questionText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // 4 Thẻ đáp án
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, optIndex) {
                          final option = options[optIndex];
                          final optionId = option['id'];
                          final optionText = option['option_text'] ?? '';
                          final isSelected = _selectedAnswers[questionId] == optionId;
                          final optionLabel = String.fromCharCode(65 + optIndex); // A, B, C, D

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedAnswers[questionId] = optionId;
                              });
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Vòng tròn nhãn A, B, C, D
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      optionLabel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      optionText,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Thanh nút điều hướng dưới cùng: Câu trước - Câu tiếp theo
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _currentIndex > 0
                            ? () => setState(() => _currentIndex--)
                            : null,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Câu trước', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _currentIndex < totalQuestions - 1
                            ? () => setState(() => _currentIndex++)
                            : null,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Câu tiếp theo', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
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
