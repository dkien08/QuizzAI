import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exam_model.dart';
import '../services/firebase_repository.dart';
import '../services/excel_service.dart';

class EditExamScreen extends StatefulWidget {
  final ExamModel exam;

  const EditExamScreen({Key? key, required this.exam}) : super(key: key);

  @override
  State<EditExamScreen> createState() => _EditExamScreenState();
}

class _EditExamScreenState extends State<EditExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final examRepo = FirebaseRepository<ExamModel>('exams', ExamModel.fromMap);

  late TextEditingController _titleController;
  late TextEditingController _categoryController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  late TextEditingController _codeController;
  late TextEditingController _passwordController;

  late bool _isPublic;
  bool _isLoading = false;
  bool _isFetchingQuestions = true;

  List<Map<String, dynamic>> _questions = [];
  int _editingIndex = -1;

  final _currentQuestionController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  int _correctAnswerIndex = 0;

  @override
  void initState() {
    super.initState();
    // 1. Nạp dữ liệu cũ của ExamModel
    _titleController = TextEditingController(text: widget.exam.title);
    _categoryController = TextEditingController(text: widget.exam.categoryTag);
    _descriptionController = TextEditingController(text: '');
    _durationController = TextEditingController(
      text: widget.exam.durationMinutes.toString(),
    );
    _codeController = TextEditingController(text: widget.exam.code);
    _passwordController = TextEditingController(
      text: widget.exam.accessPassword,
    );
    _isPublic = widget.exam.isPublic;

    // 2. Tải danh sách câu hỏi cũ từ Cloud Firestore
    _fetchExistingQuestions();
  }

  Future<void> _fetchExistingQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('exams')
          .doc(widget.exam.id)
          .collection('questions')
          .get();

      final fetched = snapshot.docs.map((doc) => doc.data()).toList();

      if (!mounted) return;
      setState(() {
        _questions = fetched;
        _isFetchingQuestions = false;
        if (_questions.isNotEmpty) {
          _loadQuestionToForm(0);
        }
      });
    } catch (e) {
      setState(() => _isFetchingQuestions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Lỗi tải câu hỏi: $e'),
        ),
      );
    }
  }

  void _loadQuestionToForm(int index) {
    if (index >= 0 && index < _questions.length) {
      setState(() {
        _editingIndex = index;
        final q = _questions[index];
        _currentQuestionController.text = q['content'] ?? '';
        List<String> opts = List<String>.from(q['options'] ?? ['', '', '', '']);
        for (int i = 0; i < 4; i++) {
          _optionControllers[i].text = i < opts.length ? opts[i] : '';
        }
        _correctAnswerIndex = q['correctAnswerIndex'] ?? 0;
      });
    }
  }

  void _resetFormForNewQuestion() {
    setState(() {
      _editingIndex = -1;
      _currentQuestionController.clear();
      for (var c in _optionControllers) {
        c.clear();
      }
      _correctAnswerIndex = 0;
    });
  }

  void _saveCurrentQuestion() {
    final content = _currentQuestionController.text.trim();
    final options = _optionControllers.map((c) => c.text.trim()).toList();
    if (content.isEmpty ||
        options.any((option) => option.isEmpty) ||
        _correctAnswerIndex < 0 ||
        _correctAnswerIndex >= options.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Cần nhập câu hỏi, đủ 4 lựa chọn và chọn đáp án đúng.'),
        ),
      );
      return;
    }

    final newQuestionData = {
      'content': content,
      'options': options,
      'correctAnswerIndex': _correctAnswerIndex,
    };

    setState(() {
      if (_editingIndex >= 0 && _editingIndex < _questions.length) {
        _questions[_editingIndex] = newQuestionData;
      } else {
        _questions.add(newQuestionData);
      }
    });

    _resetFormForNewQuestion();
  }

  Future<void> _importExcel() async {
    try {
      final imported = await ExcelService.importQuestionsFromExcel();
      if (!mounted || imported == null || imported.isEmpty) return;
      setState(() {
        _questions = imported;
        _loadQuestionToForm(0);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Lỗi nạp file Excel: $error'),
        ),
      );
    }
  }

  // Cập nhật lại Đề thi trên Cloud Firestore
  Future<void> _updateExam() async {
    if (!_formKey.currentState!.validate()) return;
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Đề thi phải có ít nhất 1 câu hỏi!'),
        ),
      );
      return;
    }
    final invalidQuestionIndex = _questions.indexWhere((question) {
      final content = question['content']?.toString().trim() ?? '';
      final options = (question['options'] as List<dynamic>? ?? const [])
          .map((option) => option.toString().trim())
          .toList();
      final correctIndex = question['correctAnswerIndex'] is num
          ? (question['correctAnswerIndex'] as num).toInt()
          : int.tryParse(question['correctAnswerIndex']?.toString() ?? '') ??
                -1;
      return content.isEmpty ||
          options.length < 4 ||
          options.any((option) => option.isEmpty) ||
          correctIndex < 0 ||
          correctIndex >= options.length;
    });
    if (invalidQuestionIndex >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text(
            'Câu hỏi ${invalidQuestionIndex + 1} chưa đủ dữ liệu hợp lệ.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedExam = ExamModel(
        id: widget.exam.id,
        title: _titleController.text.trim(),
        categoryTag: _categoryController.text.trim().toUpperCase(),
        totalQuestions: _questions.length,
        durationMinutes: int.tryParse(_durationController.text.trim()) ?? 30,
        authorName: widget.exam.authorName,
        authorId: widget.exam.authorId,
        isPublic: _isPublic,
        allowPractice: widget.exam.allowPractice,
        accessPassword: _isPublic ? '' : _passwordController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
      );

      if (!_isPublic && _passwordController.text.trim().length < 4) {
        throw Exception('Mật khẩu đề private phải có ít nhất 4 ký tự.');
      }

      await examRepo.setWithSubcollectionMaps(
        updatedExam,
        'questions',
        _questions,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Cập nhật đề thi thành công!'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Lỗi cập nhật: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const emeraldColor = Color(0xFF10B981);
    const emeraldBgColor = Color(0xFFD1FAE5);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chỉnh sửa đề thi',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Mã: ${widget.exam.code}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isFetchingQuestions
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. THÔNG TIN ĐỀ THI
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thông tin đề thi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'Tiêu đề đề thi',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              validator: (val) => val == null || val.isEmpty
                                  ? 'Vui lòng nhập tiêu đề'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _categoryController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Phân loại đề',
                                hintText: 'Ví dụ: TOÁN, LÝ, ANH',
                                prefixIcon: Icon(Icons.category_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Vui lòng nhập phân loại'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Thời gian làm bài (phút)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Công khai đề thi (is_public)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Switch(
                                  value: _isPublic,
                                  activeColor: const Color(0xFF2563EB),
                                  onChanged: (val) =>
                                      setState(() => _isPublic = val),
                                ),
                              ],
                            ),
                            if (!_isPublic)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Mật khẩu đề private',
                                    prefixIcon: Icon(Icons.key_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _importExcel,
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Nhập lại câu hỏi từ Excel'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. FORM SỬA CÂU HỎI HIỆN TẠI
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _editingIndex >= 0
                                  ? 'Chỉnh sửa câu ${_editingIndex + 1}'
                                  : 'Soạn câu hỏi mới',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _currentQuestionController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Nội dung câu hỏi...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(4, (index) {
                              final isCorrect = _correctAnswerIndex == index;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCorrect
                                        ? emeraldColor
                                        : Colors.grey.shade300,
                                  ),
                                  color: isCorrect
                                      ? emeraldBgColor
                                      : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      ['A', 'B', 'C', 'D'][index],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isCorrect
                                            ? emeraldColor
                                            : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _optionControllers[index],
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    Radio<int>(
                                      value: index,
                                      groupValue: _correctAnswerIndex,
                                      activeColor: emeraldColor,
                                      onChanged: (val) => setState(
                                        () => _correctAnswerIndex = val!,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            ElevatedButton(
                              onPressed: _saveCurrentQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                elevation: 0,
                              ),
                              child: Text(
                                _editingIndex >= 0
                                    ? 'Cập nhật câu hỏi này'
                                    : 'Thêm câu hỏi',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 3. DANH SÁCH QUAN SÁT CÂU HỎI
                      Text(
                        'Danh sách câu hỏi (${_questions.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            tileColor: Colors.white,
                            onTap: () => _loadQuestionToForm(index),
                            title: Text(_questions[index]['content'] ?? ''),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                setState(() {
                                  _questions.removeAt(index);
                                  _resetFormForNewQuestion();
                                });
                              },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // 4. NÚT LƯU CẬP NHẬT
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateExam,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  'Lưu thay đổi đề thi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _currentQuestionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
