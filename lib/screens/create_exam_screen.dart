import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/exam_model.dart';
import '../services/firebase_repository.dart';
import '../services/excel_service.dart';

class CreateExamScreen extends StatefulWidget {
  final ExamModel? exam;

  const CreateExamScreen({Key? key, this.exam}) : super(key: key);

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final examRepo = FirebaseRepository<ExamModel>('exams', ExamModel.fromMap);

  // Form Controllers
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '30');
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPublic = true;
  bool _allowPractice = true;
  bool _isLoading = false;

  // Danh sách tổng hợp các câu hỏi đã tạo
  List<Map<String, dynamic>> _questions = [];

  // Vị trí câu hỏi đang được mở để chỉnh sửa (-1 là đang thêm câu mới)
  int _editingIndex = -1;

  // Controller cho Form nhập/sửa câu hỏi hiện tại
  final _currentQuestionController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  int _correctAnswerIndex = 0;

  bool get _isEditing => widget.exam != null;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam;
    if (exam != null) {
      _titleController.text = exam.title;
      _categoryController.text = exam.categoryTag;
      _durationController.text = exam.durationMinutes.toString();
      _codeController.text = exam.code;
      _passwordController.text = exam.accessPassword;
      _isPublic = exam.isPublic;
      _loadExistingQuestions(exam.id);
    } else {
      _passwordController.text =
          'SQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  String _generateCode(String category) {
    final normalized = _normalizeCategory(category);
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    final suffix = List.generate(
      4,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
    return '$normalized-$suffix';
  }

  String _normalizeCategory(String category) {
    return category.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-');
  }

  void _updateCodePreview(String category) {
    if (_isEditing) return;
    final normalized = _normalizeCategory(category);
    if (normalized.isEmpty) {
      _codeController.clear();
      return;
    }

    final existingSuffix = RegExp(r'-([A-Z0-9]{4})$')
        .firstMatch(_codeController.text)
        ?.group(1);
    final suffix = existingSuffix ?? _generateCode(normalized).split('-').last;
    _codeController.text = '$normalized-$suffix';
  }

  Future<String> _getUniqueCode(String category) async {
    var code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty || !code.startsWith('${_normalizeCategory(category)}-')) {
      code = _generateCode(category);
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      if (!await examRepo.existsByFields({'code': code, 'isActive': true})) {
        return code;
      }
      code = _generateCode(category);
    }
    return code;
  }

  Future<void> _loadExistingQuestions(String examId) async {
    final questions = await examRepo.getSubcollectionMaps(examId, 'questions');
    if (!mounted) return;
    setState(() => _questions = questions);
  }

  // Tải thông tin câu hỏi thứ `index` lên Form nhập liệu
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

  // Reset Form để chuẩn bị thêm câu hỏi mới
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

  // Lưu hoặc Cập nhật câu hỏi hiện tại vào danh sách `_questions`
  void _saveCurrentQuestion() {
    final content = _currentQuestionController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Vui lòng nhập nội dung câu hỏi!'),
        ),
      );
      return;
    }

    final newQuestionData = {
      'content': content,
      'options': _optionControllers.map((c) => c.text.trim()).toList(),
      'correctAnswerIndex': _correctAnswerIndex,
    };

    setState(() {
      if (_editingIndex >= 0 && _editingIndex < _questions.length) {
        // Cập nhật câu hỏi cũ
        _questions[_editingIndex] = newQuestionData;
      } else {
        // Thêm mới câu hỏi vào danh sách
        _questions.add(newQuestionData);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Color.fromARGB(255, 69, 108, 147),
        content: Text(
          _editingIndex >= 0
              ? 'Đã cập nhật câu ${_editingIndex + 1}!'
              : 'Đã thêm câu mới thành công!',
        ),
      ),
    );

    _resetFormForNewQuestion();
  }

  // Nạp câu hỏi từ file Excel (.xlsx)
  Future<void> _importExcel() async {
    try {
      final imported = await ExcelService.importQuestionsFromExcel();
      if (imported != null && imported.isNotEmpty) {
        setState(() {
          _questions = imported;
          _loadQuestionToForm(0);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Color.fromARGB(255, 69, 108, 147),
            content: Text(
              'Đã nạp thành công ${imported.length} câu hỏi từ file Excel!',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Lỗi nạp file Excel: $e'),
        ),
      );
    }
  }

  // Lưu và Xuất bản đề thi lên Cloud Firestore
  Future<void> _saveAndPublishExam({bool isDraft = false}) async {
    if (!isDraft && !(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Vui lòng nhập tiêu đề và phân loại đề thi.'),
        ),
      );
      return;
    }
    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Vui lòng thêm ít nhất 1 câu hỏi!'),
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
            'Câu hỏi ${invalidQuestionIndex + 1} chưa đủ 4 lựa chọn hoặc chưa có đáp án đúng hợp lệ.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docId =
          widget.exam?.id ??
          FirebaseFirestore.instance.collection('exams').doc().id;

      final category = _categoryController.text.trim();
      if (category.isEmpty) {
        throw Exception('Vui lòng nhập phân loại đề thi.');
      }
      final code = _isEditing
          ? _codeController.text.trim().toUpperCase()
          : await _getUniqueCode(category);
      final newExam = ExamModel(
        id: docId,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Đề thi nháp',
        categoryTag: category.toUpperCase(),
        totalQuestions: _questions.length,
        durationMinutes: int.tryParse(_durationController.text.trim()) ?? 30,
        authorName: 'Giáo viên',
        authorId: FirebaseAuth.instance.currentUser?.uid ?? '',
        isPublic: _isPublic,
        allowPractice: _allowPractice,
        accessPassword: _isPublic ? '' : _passwordController.text.trim(),
        code: code,
      );

      if (!_isPublic && _passwordController.text.trim().length < 4) {
        throw Exception('Mật khẩu đề private phải có ít nhất 4 ký tự.');
      }

      await examRepo.setWithSubcollectionMaps(newExam, 'questions', _questions);

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Color.fromARGB(255, 69, 108, 147),
          content: Text(
            isDraft
                ? 'Đã lưu bản nháp đề thi!'
                : 'Tạo và xuất bản đề thi thành công!',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text('Lỗi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Tạo đề thi mới',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Thiết lập thông tin và câu hỏi',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==========================================
                // 1. THÔNG TIN ĐỀ THI CARD
                // ==========================================
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

                      const Text(
                        'Tiêu đề',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Nhập tiêu đề',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
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
                        decoration: InputDecoration(
                          labelText: 'Phân loại đề',
                          hintText: 'Ví dụ: TOÁN, LÝ, ANH',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập phân loại'
                            : null,
                        onChanged: _updateCodePreview,
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Mô tả',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Nhập mô tả',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Thời gian làm bài',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.access_time, size: 20),
                          suffixText: 'phút',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
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
                            onChanged: (val) => setState(() => _isPublic = val),
                          ),
                        ],
                      ),

                      if (!_isPublic) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu đề private',
                            hintText: 'Tối thiểu 4 ký tự',
                            prefixIcon: const Icon(Icons.key_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Cho phép ôn tập (allow_practice)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: _allowPractice,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) =>
                                setState(() => _allowPractice = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ==========================================
                // 2. NÚT IMPORT EXCEL & THÊM CÂU HỎI THỦ CÔNG
                // ==========================================
                OutlinedButton.icon(
                  onPressed: _importExcel,
                  icon: const Icon(
                    Icons.table_chart_outlined,
                    color: Color.fromARGB(255, 69, 108, 147),
                  ),
                  label: const Text(
                    'Nhập từ file Excel',
                    style: TextStyle(
                      color: Color.fromARGB(255, 69, 108, 147),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: const BorderSide(
                      color: Color.fromARGB(255, 69, 108, 147),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                OutlinedButton.icon(
                  onPressed: _resetFormForNewQuestion,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF2563EB),
                  ),
                  label: const Text(
                    'Soạn câu hỏi mới',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 6, bottom: 16),
                    child: Text(
                      'Hỗ trợ .xlsx theo mẫu Smart Quiz - tối đa 100 câu hỏi',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ),
                ),

                // ==========================================
                // 3. FORM NHẬP / CHỈNH SỬA CÂU HỎI HIỆN TẠI
                // ==========================================
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: const Color(0xFF2563EB),
                                child: Text(
                                  _editingIndex >= 0
                                      ? '${_editingIndex + 1}'
                                      : '+',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _editingIndex >= 0
                                    ? 'Chỉnh sửa câu ${_editingIndex + 1}'
                                    : 'Soạn câu hỏi mới',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (_editingIndex >= 0)
                            TextButton(
                              onPressed: _resetFormForNewQuestion,
                              child: const Text('Thêm câu mới'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Nội dung câu hỏi',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _currentQuestionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Nhập câu hỏi...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Lựa chọn và đáp án đúng',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),

                      // 4 Đáp án A, B, C, D
                      ...List.generate(4, (index) {
                        final labels = ['A', 'B', 'C', 'D'];
                        final isCorrect = _correctAnswerIndex == index;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCorrect
                                  ? Color.fromARGB(255, 69, 108, 147)
                                  : Colors.grey.shade300,
                            ),
                            color: isCorrect
                                ? Color.fromARGB(
                                    255,
                                    69,
                                    108,
                                    147,
                                  ).withOpacity(0.1)
                                : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Text(
                                labels[index],
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect
                                      ? Color.fromARGB(255, 69, 108, 147)
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _optionControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Đáp án ${labels[index]}',
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              Radio<int>(
                                value: index,
                                groupValue: _correctAnswerIndex,
                                activeColor: Color.fromARGB(255, 69, 108, 147),
                                onChanged: (val) =>
                                    setState(() => _correctAnswerIndex = val!),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),

                      // Nút Lưu/Xóa câu hỏi
                      Row(
                        children: [
                          if (_editingIndex >= 0)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _questions.removeAt(_editingIndex);
                                    _resetFormForNewQuestion();
                                  });
                                },
                                child: const Text(
                                  'Xóa câu này',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          if (_editingIndex >= 0) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveCurrentQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                elevation: 0,
                              ),
                              child: Text(
                                _editingIndex >= 0
                                    ? 'Cập nhật câu ${_editingIndex + 1}'
                                    : 'Thêm vào danh sách',
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ==========================================
                // 4. DANH SÁCH QUAN SÁT CÁC CÂU HỎI ĐÃ TẠO
                // ==========================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Danh sách câu hỏi đã có (${_questions.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_questions.isNotEmpty)
                      const Text(
                        'Nhấn để sửa',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_questions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text(
                        'Chưa có câu hỏi nào. Hãy nhập câu hỏi ở trên hoặc import từ Excel!',
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _questions.length,
                    itemBuilder: (context, index) {
                      final q = _questions[index];
                      final isSelected = index == _editingIndex;
                      final List options = q['options'] ?? [];
                      final int correctIdx = q['correctAnswerIndex'] ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.blue.shade50
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _loadQuestionToForm(index),
                          leading: CircleAvatar(
                            radius: 14,
                            backgroundColor: isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade200,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            q['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Đáp án đúng: ${correctIdx < options.length ? options[correctIdx] : "N/A"}',
                              style: const TextStyle(
                                color: Color.fromARGB(255, 69, 108, 147),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _questions.removeAt(index);
                                if (_editingIndex == index) {
                                  _resetFormForNewQuestion();
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 28),

                // ==========================================
                // 5. CỤM NÚT LƯU ĐỀ THI VÀ LƯU BẢN NHÁP
                // ==========================================
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => _saveAndPublishExam(isDraft: false),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                    ),
                    label: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Lưu và xuất bản đề thi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _saveAndPublishExam(isDraft: true),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Lưu bản nháp',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
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
