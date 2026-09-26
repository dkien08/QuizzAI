import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String baseUrl = 'https://quizzapp-kovj.onrender.com';
  final TextEditingController _codeController = TextEditingController();
  
  late Future<List<dynamic>> _publicExamsFuture;
  bool _isEnteringExam = false;

  @override
  void initState() {
    super.initState();
    _publicExamsFuture = _fetchPublicExams();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // Gọi API lấy danh sách đề thi công khai (GET /exams)
  Future<List<dynamic>> _fetchPublicExams() async {
    final response = await http.get(Uri.parse('$baseUrl/exams'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể tải danh sách đề thi');
    }
  }

  // Tìm và vào thi bằng mã code (GET /exams/code/:code)
  Future<void> _enterExamByCode(String code) async {
    final trimmedCode = code.trim();
    if (trimmedCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã đề thi')),
      );
      return;
    }

    setState(() => _isEnteringExam = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/exams/code/$trimmedCode'));
      if (response.statusCode == 200) {
        final examData = jsonDecode(response.body);
        if (!mounted) return;
        // Chuyển sang màn hình thi thật (không mang theo đáp án đúng)
        Navigator.pushNamed(context, '/exam/take', arguments: examData);
      } else {
        final error = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error['message'] ?? 'Không tìm thấy mã đề thi này')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối máy chủ, vui lòng thử lại')),
      );
    } finally {
      if (mounted) setState(() => _isEnteringExam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Smart Quiz',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Kho đề thi & Phòng thi mở',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _publicExamsFuture = _fetchPublicExams();
              });
            },
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            tooltip: 'Làm mới danh sách',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _publicExamsFuture = _fetchPublicExams();
            });
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Ô tìm kiếm / Nhập mã đề thi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_outlined, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            hintText: 'Nhập mã đề thi (Code) để vào phòng...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            border: InputBorder.none,
                          ),
                          onSubmitted: _enterExamByCode,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isEnteringExam
                            ? null
                            : () => _enterExamByCode(_codeController.text),
                        icon: _isEnteringExam
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 2. Tiêu đề danh sách đề thi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kho đề thi mở',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _publicExamsFuture = _fetchPublicExams();
                        });
                      },
                      child: const Text('Xem tất cả'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 3. Danh sách đề thi từ API thật
                FutureBuilder<List<dynamic>>(
                  future: _publicExamsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 60.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Column(
                            children: [
                              const Icon(Icons.wifi_off, size: 48, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 12),
                              Text('Lỗi kết nối: ${snapshot.error}'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _publicExamsFuture = _fetchPublicExams();
                                  });
                                },
                                child: const Text('Tải lại'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final exams = snapshot.data ?? [];
                    if (exams.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            'Hiện chưa có đề thi công khai nào',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: exams.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final exam = exams[index];
                        final title = exam['title'] ?? 'Bài kiểm tra';
                        final duration = exam['duration'] ?? 0;
                        final questionCount = exam['question_count'] ?? exam['total_questions'] ?? 0;
                        final author = exam['author_name'] ?? exam['creator_name'] ?? 'Giảng viên';
                        final code = exam['code'] ?? '';

                        // Lấy ký tự viết tắt hiển thị biểu tượng môn học
                        final tagText = title.length >= 4
                            ? title.substring(0, 4).toUpperCase()
                            : 'THI';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Badge viết tắt môn thi
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      tagText,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Thông tin tiêu đề & số câu
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$questionCount câu · $duration phút',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tác giả: $author',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Nút bắt đầu thi
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (code.isNotEmpty) {
                                      _enterExamByCode(code);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    foregroundColor: const Color(0xFF2563EB),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Bắt đầu thi',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}