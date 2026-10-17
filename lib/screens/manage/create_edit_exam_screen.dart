import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class CreateEditExamScreen extends StatefulWidget {
  final Map<String, dynamic>? initialExam;
  const CreateEditExamScreen({super.key, this.initialExam});

  @override
  State<CreateEditExamScreen> createState() => _CreateEditExamScreenState();
}

class _CreateEditExamScreenState extends State<CreateEditExamScreen> {
  static const String baseUrl = 'https://quizzapp-kovj.onrender.com';

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _durationController = TextEditingController(text: '30');

  bool _isPublic = true;
  bool _allowPractice = true;
  bool _isLoading = false;

  // Danh sách các câu hỏi tự soạn thủ công
  final List<Map<String, dynamic>> _questions = [];

  // Ô soạn câu hỏi hiện tại
  final _currentQuestionTextController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(4, (_) => TextEditingController());
  int _correctOptionIndex = 0; // Mặc định đáp án A đúng

  bool get _isEditMode => widget.initialExam != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final exam = widget.initialExam!;
      _titleController.text = exam['title'] ?? '';
      _descController.text = exam['description'] ?? '';
      _durationController.text = (exam['duration'] ?? 30).toString();
      _isPublic = exam['is_public'] == 1 || exam['is_public'] == true;
      _allowPractice = exam['allow_practice'] == 1 || exam['allow_practice'] == true;
      _fetchExistingQuestions(exam['id']);
    }
  }

  Future<void> _fetchExistingQuestions(int examId) async {
    final token = await AuthService.getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/exams/$examId/questions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final questions = data['questions'] as List<dynamic>? ?? [];
      setState(() {
        _questions.addAll(questions.map((q) => {
          'question_text': q['question_text'],
          'options': q['options'],
        }));
      });
    }
  }

  void _addManualQuestion() {
    final text = _currentQuestionTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập nội dung câu hỏi')));
      return;
    }

    final options = <Map<String, dynamic>>[];
    for (int i = 0; i < 4; i++) {
      final optText = _optionControllers[i].text.trim();
      if (optText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vui lòng điền đủ đáp án ${String.fromCharCode(65 + i)}')));
        return;
      }
      options.add({
        'option_text': optText,
        'is_correct': _correctOptionIndex == i ? 1 : 0,
      });
    }

    setState(() {
      _questions.add({
        'question_text': text,
        'options': options,
      });
      _currentQuestionTextController.clear();
      for (var c in _optionControllers) {
        c.clear();
      }
      _correctOptionIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm 1 câu hỏi vào danh sách!')));
  }

  Future<void> _saveExam() async {
    final title = _titleController.text.trim();
    final duration = int.tryParse(_durationController.text.trim()) ?? 30;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tiêu đề đề thi')));
      return;
    }

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đề thi phải có ít nhất 1 câu hỏi')));
      return;
    }

    setState(() => _isLoading = true);
    final token = await AuthService.getToken();

    final body = jsonEncode({
      'title': title,
      'description': _descController.text.trim(),
      'duration': duration,
      'is_public': _isPublic ? 1 : 0,
      'allow_practice': _allowPractice ? 1 : 0,
      'questions': _questions,
    });

    try {
      http.Response res;
      if (_isEditMode) {
        final examId = widget.initialExam!['id'];
        res = await http.put(
          Uri.parse('$baseUrl/exams/$examId'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: body,
        );
      } else {
        res = await http.post(
          Uri.parse('$baseUrl/exams/create'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: body,
        );
      }

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? 'Cập nhật đề thành công!' : 'Tạo đề thi mới thành công!')),
        );
        Navigator.pop(context, true);
      } else {
        final err = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err['message'] ?? 'Lỗi lưu đề thi')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối máy chủ')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Color(0xFF0F172A)),
        title: Text(
          _isEditMode ? 'Chỉnh sửa đề thi' : 'Tạo đề thi mới',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Khung thông tin đề thi
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin đề thi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Tiêu đề đề thi', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Mô tả ngắn', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thời gian làm bài (phút)',
                      prefixIcon: Icon(Icons.timer_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Công khai đề thi (is_public)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    value: _isPublic,
                    onChanged: (val) => setState(() => _isPublic = val),
                  ),
                  SwitchListTile(
                    title: const Text('Cho phép ôn tập (allow_practice)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    value: _allowPractice,
                    onChanged: (val) => setState(() => _allowPractice = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Nút Thêm câu hỏi / Nhập Excel
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng chọn file .xlsx đúng định dạng cột A-F của hệ thống')),
                      );
                    },
                    icon: const Icon(Icons.table_chart_outlined, color: Color(0xFF059669)),
                    label: const Text('Nhập từ file Excel', style: TextStyle(color: Color(0xFF059669))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFF059669)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Soạn thảo câu hỏi thủ công
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Soạn câu hỏi (${_questions.length + 1})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2563EB)),
                      ),
                      const Text('Chọn nút tròn để chỉ định đáp án đúng', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _currentQuestionTextController,
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'Nhập nội dung câu hỏi...', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(4, (index) {
                    final label = String.fromCharCode(65 + index);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: index,
                            groupValue: _correctOptionIndex,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) => setState(() => _correctOptionIndex = val!),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _optionControllers[index],
                              decoration: InputDecoration(
                                hintText: 'Đáp án $label',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _addManualQuestion,
                      icon: const Icon(Icons.add),
                      label: const Text('Lưu câu hỏi này vào đề'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFF6FF),
                        foregroundColor: const Color(0xFF2563EB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Nút Lưu đề chính thức
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveExam,
                icon: const Icon(Icons.check_circle_outline),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Lưu và xuất bản đề thi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}