import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exam_model.dart';
import '../services/firebase_repository.dart';
import 'generic_quiz_screen.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({Key? key}) : super(key: key);

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final _codeController = TextEditingController();
  final _examRepo = FirebaseRepository<ExamModel>('exams', ExamModel.fromMap);
  bool _isSearching = false;
  String _categoryFilter = '';
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _matchesCategory(ExamModel exam) {
    final filter = _categoryFilter.trim().toLowerCase();
    return filter.isEmpty || exam.categoryTag.toLowerCase().contains(filter);
  }

  Future<bool> _hasSubmitted(String examId) async {
    if (_userId.isEmpty) return true;
    final snapshot = await FirebaseFirestore.instance
        .collection('exam_submissions')
        .where('examId', isEqualTo: examId)
        .where('userId', isEqualTo: _userId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> _startExamSession(ExamModel exam) async {
    final sessionId = '${exam.id}_$_userId';
    try {
      await FirebaseFirestore.instance
          .collection('exam_sessions')
          .doc(sessionId)
          .set({
            'examId': exam.id,
            'userId': _userId,
            'status': 'active',
            'startedAt': FieldValue.serverTimestamp(),
          });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openOfficialExam(ExamModel exam) async {
    if (!exam.isActive) {
      _showMessage('Đề thi này không còn mở cho người dùng.');
      return;
    }
    if (_userId.isEmpty) {
      _showMessage('Vui lòng đăng nhập để tham gia thi.');
      return;
    }

    try {
      if (!exam.isPublic && !await _verifyPrivatePassword(exam)) return;
      if (await _hasSubmitted(exam.id)) {
        _showMessage('Bạn đã nộp bài này và không thể thi lại.');
        return;
      }
      final questions = await _examRepo.getSubcollectionMaps(
        exam.id,
        'questions',
      );
      final sessionStarted = await _startExamSession(exam);
      if (!sessionStarted) {
        _showMessage('Bạn đã vào hoặc đã hoàn thành bài thi này trước đó.');
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GenericQuizScreen(
            examId: exam.id,
            examSessionId: '${exam.id}_$_userId',
            examTitle: exam.title,
            durationMinutes: exam.durationMinutes,
            isPracticeMode: false,
            questions: questions,
          ),
        ),
      );
    } catch (error) {
      _showMessage('Không thể mở phòng thi: $error');
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
      _showMessage('Mật khẩu đề thi không đúng.');
      return false;
    }
    return true;
  }

  Future<void> _joinExamByCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showMessage('Vui lòng nhập mã phòng thi!');
      return;
    }

    setState(() => _isSearching = true);
    try {
      final exams = await _examRepo
          .getRealtimeList(whereField: 'isActive', whereValue: true)
          .first;
      final matches = exams.where(
        (exam) => exam.code.toUpperCase() == code && exam.isActive,
      );
      final exam = matches.isEmpty ? null : matches.first;
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        if (exam == null) _categoryFilter = code;
      });
      if (exam == null) {
        return;
      }
      await _openOfficialExam(exam);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      _showMessage('Lỗi kết nối: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Phòng thi chính thức',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<ExamModel>>(
        stream: _examRepo.getRealtimeList(
          whereField: 'isActive',
          whereValue: true,
        ),
        builder: (context, snapshot) {
          final publicExams = (snapshot.data ?? [])
              .where(
                (exam) =>
                    exam.isActive && exam.isPublic && _matchesCategory(exam),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildCodeEntry(),
              const SizedBox(height: 24),
              const Text(
                'Đề thi public',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (snapshot.hasError)
                Text('Lỗi tải đề thi: ${snapshot.error}')
              else if (publicExams.isEmpty)
                const Text(
                  'Hiện chưa có đề thi public nào.',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...publicExams.map(_buildExamCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCodeEntry() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vào thi bằng mã phòng',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Nhập mã đề hoặc phân loại (VD: MATH-2609, toán)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _codeController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _codeController.clear();
                              setState(() => _categoryFilter = '');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                  onChanged: (value) => setState(() => _categoryFilter = value),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSearching ? null : _joinExamByCode,
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Vào thi'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(ExamModel exam) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.lock_outline, color: Colors.red.shade700),
        ),
        title: Text(
          exam.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PUBLIC · ${exam.categoryTag} · ${exam.durationMinutes} phút · ${exam.totalQuestions} câu',
            ),
            Row(
              children: [
                Expanded(child: Text('Mã: ${exam.code}')),
                IconButton(
                  tooltip: 'Sao chép mã đề',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_outlined, size: 17),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: exam.code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã sao chép mã đề.')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _openOfficialExam(exam),
          child: const Text('Thi ngay'),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}
