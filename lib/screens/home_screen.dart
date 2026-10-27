import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/exam_model.dart';
import '../models/user_model.dart';
import '../services/firebase_repository.dart';
import '../widgets/generic_card.dart';
import 'generic_quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const HomeScreen({Key? key, this.onNavigate}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final examRepo = FirebaseRepository<ExamModel>('exams', ExamModel.fromMap);
  final userRepo = FirebaseRepository<UserModel>('users', UserModel.fromMap);

  final TextEditingController _codeController = TextEditingController();
  bool _isSearchingCode = false;
  bool _showAllMyExams = false;
  bool _showAllPublicExams = false;
  String _categoryFilter = '';

  // Lấy ID người dùng hiện tại từ Firebase Auth
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _matchesCategory(ExamModel exam) {
    final filter = _categoryFilter.trim().toLowerCase();
    return filter.isEmpty || exam.categoryTag.toLowerCase().contains(filter);
  }

  void _resetHomeView() {
    final hasStateToReset =
        _codeController.text.isNotEmpty ||
        _categoryFilter.isNotEmpty ||
        _showAllMyExams ||
        _showAllPublicExams;
    if (!hasStateToReset) return;

    _codeController.clear();
    setState(() {
      _categoryFilter = '';
      _showAllMyExams = false;
      _showAllPublicExams = false;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đặt lại bộ lọc trang chủ.')),
    );
  }

  // Hàm xử lý vào phòng thi bằng mã Code thật
  Future<void> _joinExamByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã phòng thi!')),
      );
      return;
    }

    setState(() => _isSearchingCode = true);

    try {
      // Tìm kiếm đề thi trong Firebase Firestore có field 'code' == code vừa nhập
      final exam = await examRepo.getOneByField('code', code);

      if (!mounted) return;
      setState(() => _isSearchingCode = false);

      if (exam != null) {
        if (!exam.isPublic && !await _verifyPrivatePassword(exam)) {
          if (mounted) setState(() => _isSearchingCode = false);
          return;
        }
        final questions = await examRepo.getSubcollectionMaps(
          exam.id,
          'questions',
        );
        if (!mounted) return;
        setState(() => _isSearchingCode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Tìm thấy đề: ${exam.title} (${exam.totalQuestions} câu)',
            ),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GenericQuizScreen(
              examTitle: exam.title,
              durationMinutes: exam.durationMinutes,
              isPracticeMode: true,
              questions: questions,
            ),
          ),
        );
      } else {
        // Mã không tồn tại hoặc đề bị ẩn
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text('Mã phòng thi không tồn tại hoặc đã bị khóa!'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearchingCode = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi kết nối: $e')));
    }
  }

  Future<bool> _verifyPrivatePassword(ExamModel exam) async {
    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đề thi private'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Mật khẩu đề thi',
            prefixIcon: Icon(Icons.key_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, passwordController.text),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null) return false;
    if (password != exam.accessPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mật khẩu đề thi không đúng.')),
        );
      }
      return false;
    }
    return true;
  }

  Widget _buildExamSection({
    required String title,
    required List<ExamModel> exams,
    required String emptyMessage,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (actionText != null)
              TextButton(onPressed: onAction, child: Text(actionText)),
          ],
        ),
        const SizedBox(height: 12),
        if (exams.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              emptyMessage,
              style: const TextStyle(color: Colors.grey),
            ),
          )
        else
          ...exams.map(_buildPracticeCard),
      ],
    );
  }

  Widget _buildPracticeCard(ExamModel exam) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GenericCard<ExamModel>(
        data: exam,
        getTag: (item) => item.categoryTag,
        getIsPublic: (item) => item.isPublic,
        getCode: (item) => item.code,
        getTitle: (item) => item.title,
        getSubtitle: (item) =>
            'Mã: ${item.code.isNotEmpty ? item.code : "N/A"} · ${item.durationMinutes} phút · ${item.totalQuestions} câu',
        actionLabel: 'Luyện tập ngay',
        onTap: () async {
          if (!exam.isPublic && !await _verifyPrivatePassword(exam)) return;
          final questions = await examRepo.getSubcollectionMaps(
            exam.id,
            'questions',
          );
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GenericQuizScreen(
                examTitle: exam.title,
                durationMinutes: exam.durationMinutes,
                isPracticeMode: true,
                questions: questions,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER & HERO STREAK LẤY DATA THẬT TỪ FIREBASE USER
              StreamBuilder<UserModel?>(
                stream: currentUserId.isNotEmpty
                    ? userRepo.getRealtimeById(currentUserId)
                    : const Stream.empty(),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final displayName = user?.fullName.isNotEmpty == true
                      ? user!.fullName
                      : 'Bạn mới';
                  final streak = user?.streakDays ?? 0;

                  return Column(
                    children: [
                      // Header Lời chào
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade700,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.psychology,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Smart Quiz',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Chào buổi sáng, $displayName!',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Đặt lại trang chủ',
                            icon: const Icon(Icons.restart_alt, size: 28),
                            onPressed: _resetHomeView,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Hero Card Chuỗi Học Tập Real-time
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.indigo.shade800,
                              Colors.blue.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'HÔM NAY',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Giữ vững chuỗi luyện tập',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bạn đã duy trì chuỗi học $streak ngày liên tiếp.',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '$streak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // 2. Ô NHẬP MÃ CODE THẬT VÀO PHÒNG
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.vpn_key_outlined, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization
                            .characters, // Tự viết hoa mã code
                        decoration: const InputDecoration(
                          hintText: 'Nhập mã đề thi (VD: MATH-2609)...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _isSearchingCode ? null : _joinExamByCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                      child: _isSearchingCode
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_forward,
                              color: Colors.white,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm theo phân loại đề (VD: toán, lý, anh)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _categoryFilter.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() => _categoryFilter = ''),
                          icon: const Icon(Icons.clear),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _categoryFilter = value),
              ),
              const SizedBox(height: 16),

              StreamBuilder<List<ExamModel>>(
                stream: examRepo.getRealtimeList(
                  whereField: 'isActive',
                  whereValue: true,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Lỗi tải đề thi: ${snapshot.error}');
                  }

                  final exams = snapshot.data ?? <ExamModel>[];
                  final myExams = exams
                      .where(
                        (exam) =>
                            exam.authorId == currentUserId &&
                            _matchesCategory(exam),
                      )
                      .toList();
                  final publicExams = exams
                      .where(
                        (exam) =>
                            exam.isActive &&
                            exam.isPublic &&
                            _matchesCategory(exam),
                      )
                      .toList();
                  final visiblePublicExams = _showAllPublicExams
                      ? publicExams
                      : publicExams.take(3).toList();
                  final visibleMyExams = _showAllMyExams
                      ? myExams
                      : myExams.take(3).toList();

                  return Column(
                    children: [
                      _buildExamSection(
                        title: 'Đề thi của tôi',
                        exams: visibleMyExams,
                        emptyMessage: 'Bạn chưa tạo đề thi nào.',
                        actionText: myExams.length > 3
                            ? (_showAllMyExams ? 'Thu gọn' : 'Xem thêm')
                            : null,
                        onAction: () =>
                            setState(() => _showAllMyExams = !_showAllMyExams),
                      ),
                      const SizedBox(height: 16),
                      _buildExamSection(
                        title: 'Đề thi public',
                        exams: visiblePublicExams,
                        emptyMessage: 'Chưa có đề thi public nào.',
                        actionText: publicExams.length > 3
                            ? (_showAllPublicExams ? 'Thu gọn' : 'Xem thêm')
                            : null,
                        onAction: () => setState(
                          () => _showAllPublicExams = !_showAllPublicExams,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
