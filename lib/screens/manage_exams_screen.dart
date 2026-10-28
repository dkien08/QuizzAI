import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/exam_model.dart';
import '../services/firebase_repository.dart';
import 'create_exam_screen.dart';
import 'edit_exam_screen.dart';
import 'exam_stats_screen.dart';

class ManageExamsScreen extends StatefulWidget {
  const ManageExamsScreen({Key? key}) : super(key: key);

  @override
  State<ManageExamsScreen> createState() => _ManageExamsScreenState();
}

class _ManageExamsScreenState extends State<ManageExamsScreen> {
  final FirebaseRepository<ExamModel> _examRepository =
      FirebaseRepository<ExamModel>('exams', ExamModel.fromMap);

  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Công khai, 2: Riêng tư
  final _searchController = TextEditingController();
  String _searchText = '';

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<List<ExamModel>> get _ownedExams {
    return _examRepository.getRealtimeList(
      whereField: 'authorId',
      whereValue: _userId,
    );
  }

  void _navigateToCreateExam() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateExamScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // 1. HEADER (Tiêu đề + Thống kê + Nút Tạo đề)
            // ==========================================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đề thi của tôi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<List<ExamModel>>(
                        stream: _ownedExams,
                        builder: (context, snapshot) {
                          final count = snapshot.data?.length ?? 0;
                          return Text(
                            '$count đề đang hoạt động',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _navigateToCreateExam,
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text(
                      'Tạo đề',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF2563EB,
                      ), // Xanh lam chuẩn thiết kế
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // 2. FILTER TABS (Tất cả, Công khai, Riêng tư)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildFilterTab(0, 'Tất cả'),
                  const SizedBox(width: 8),
                  _buildFilterTab(1, 'Công khai'),
                  const SizedBox(width: 8),
                  _buildFilterTab(2, 'Riêng tư'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, phân loại hoặc mã đề',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchText.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchText = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _searchText = value),
              ),
            ),
            const SizedBox(height: 12),

            // ==========================================
            // 3. DANH SÁCH BÀI THI REALTIME TỪ FIREBASE
            // ==========================================
            Expanded(
              child: StreamBuilder<List<ExamModel>>(
                stream: _ownedExams,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Không thể tải danh sách đề: ${snapshot.error}',
                      ),
                    );
                  }

                  // Lọc dữ liệu theo Filter Tab đang chọn
                  List<ExamModel> exams = (snapshot.data ?? <ExamModel>[])
                      .where(_matchesSearch)
                      .toList();
                  if (_selectedFilterIndex == 1) {
                    exams = exams.where((e) => e.isPublic).toList();
                  } else if (_selectedFilterIndex == 2) {
                    exams = exams.where((e) => !e.isPublic).toList();
                  }

                  if (exams.isEmpty) {
                    return const Center(
                      child: Text('Không có đề thi phù hợp với bộ lọc.'),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      return _buildExamCard(exam);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesSearch(ExamModel exam) {
    final query = _searchText.trim().toLowerCase();
    return query.isEmpty ||
        exam.title.toLowerCase().contains(query) ||
        exam.categoryTag.toLowerCase().contains(query) ||
        exam.code.toLowerCase().contains(query);
  }

  // Widget tạo nút Filter Tab
  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return StreamBuilder<List<ExamModel>>(
      stream: _ownedExams,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          final ownedExams = snapshot.data!;
          if (index == 0) count = ownedExams.length;
          if (index == 1) count = ownedExams.where((e) => e.isPublic).length;
          if (index == 2) count = ownedExams.where((e) => !e.isPublic).length;
        }

        return ChoiceChip(
          label: Text('$label $count'),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedFilterIndex = index);
            }
          },
          selectedColor: Colors.blue.shade50,
          backgroundColor: Colors.transparent,
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          side: BorderSide(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          showCheckmark: false,
        );
      },
    );
  }

  // Widget dựng CARD ĐỀ THI Y HỆT TRONG MOCKUP (Hình 3)
  Widget _buildExamCard(ExamModel exam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon File Đề thi
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              // Thông tin Đề thi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildSubmissionCount(exam),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sao chép mã đề',
                icon: const Icon(Icons.copy_outlined, size: 19),
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
          const SizedBox(height: 12),

          // Badges Tag trạng thái (Public/Private & Cho phép ôn tập)
          Row(
            children: [
              _buildBadge(
                label: exam.isPublic ? 'Public' : 'Private',
                bgColor: exam.isPublic
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                textColor: exam.isPublic
                    ? Colors.green.shade700
                    : Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              _buildBadge(
                label: 'Cho phép ôn tập',
                bgColor: Colors.blue.shade50,
                textColor: const Color(0xFF2563EB),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // 3 Nút Thao tác: Sửa đề | Thống kê | Xóa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: Icons.edit_outlined,
                label: 'Sửa đề',
                color: Colors.blue.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditExamScreen(exam: exam),
                  ),
                ),
              ),
              _buildActionButton(
                icon: Icons.bar_chart_outlined,
                label: 'Thống kê',
                color: Colors.blue.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExamStatsScreen(exam: exam),
                  ),
                ),
              ),
              _buildActionButton(
                icon: Icons.delete_outline,
                label: 'Xóa',
                color: Colors.red.shade600,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Xóa đề thi?'),
                      content: Text(
                        'Bạn có chắc muốn xóa "${exam.title}"? Câu hỏi của đề cũng sẽ bị xóa.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await _examRepository.deleteWithSubcollection(
                    exam.id,
                    'questions',
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa đề thi.')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCount(ExamModel exam) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('exam_submissions')
          .where('examId', isEqualTo: exam.id)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Text(
          'Mã: ${exam.code.isNotEmpty ? exam.code : "N/A"} · $count lượt làm',
          style: const TextStyle(fontSize: 12, color: Colors.blue),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildBadge({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
