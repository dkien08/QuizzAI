import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _currentUser = FirebaseAuth.instance.currentUser;

  // Dữ liệu mặc định (sẽ được cập nhật realtime từ Firestore)
  String _fullName = 'Chưa cập nhật';
  String _username = '@user';
  String _joinDate = 'Chưa cập nhật ngày tham gia';
  int _examsTaken = 0;
  double _avgScore = 0;
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Đọc dữ liệu cá nhân & thống kê của User từ Firestore (Dữ liệu thật)
  Future<void> _loadUserData() async {
    if (_currentUser == null) return;
    final user = _currentUser!;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final submissionSnapshot = await FirebaseFirestore.instance
          .collection('exam_submissions')
          .where('userId', isEqualTo: user.uid)
          .get();
      final submissions = submissionSnapshot.docs
          .map((doc) => doc.data())
          .where(
            (data) =>
                data['status'] == 'submitted' || data['status'] == 'timeout',
          )
          .toList();
      final totalScore = submissions.fold<double>(0, (sum, data) {
        final correct = (data['correctCount'] as num?)?.toDouble() ?? 0;
        final total = (data['totalQuestions'] as num?)?.toDouble() ?? 0;
        return sum + (total == 0 ? 0 : correct / total * 10);
      });
      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        final storedStreak = (data['streakDays'] as num?)?.toInt();
        setState(() {
          _fullName = data['fullName'] ?? user.displayName ?? 'Chưa cập nhật';
          _username =
              data['username'] ?? user.email?.split('@').first ?? 'user';
          if (!_username.startsWith('@')) {
            _username = '@$_username';
          }
          // Thống kê thật
          _examsTaken = submissions.length;
          _avgScore = submissions.isEmpty ? 0 : totalScore / submissions.length;
          _streakDays = storedStreak ?? 0;

          // Xử lý ngày tham gia
          if (data['createdAt'] != null) {
            final createdAt = data['createdAt'];
            final date = createdAt is Timestamp
                ? createdAt.toDate()
                : user.metadata.creationTime;
            if (date == null) return;
            _joinDate =
                "Tham gia từ ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
          }
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải thông tin user: $e");
    }
  }

  // Chức năng Đăng xuất
  void _handleSignOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn thoát khỏi Smart Quiz trên thiết bị này?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
            },
            child: const Text(
              'Đăng xuất',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeDisplayName() async {
    if (_currentUser == null) return;
    final controller = TextEditingController(text: _fullName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên hiển thị'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Họ và tên mới'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      await _currentUser!.updateDisplayName(name);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .set({
            'fullName': name,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _fullName = name);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật tên hiển thị.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể đổi tên: $error')));
    }
  }

  Future<void> _changePassword() async {
    if (_currentUser == null) return;
    final email = _currentUser!.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tài khoản hiện tại không dùng đăng nhập bằng email.'),
        ),
      );
      return;
    }
    final passwords = await showDialog<List<String>>(
      context: context,
      builder: (context) => _ChangePasswordDialog(
        onSubmit: (oldPassword, newPassword) async {
          try {
            final credential = EmailAuthProvider.credential(
              email: email,
              password: oldPassword,
            );
            await _currentUser!.reauthenticateWithCredential(credential);
            await _currentUser!.updatePassword(newPassword);
            return null;
          } on FirebaseAuthException catch (error) {
            return error.code == 'wrong-password' ||
                    error.code == 'invalid-credential'
                ? 'Mật khẩu hiện tại không đúng.'
                : error.code == 'requires-recent-login'
                ? 'Vui lòng đăng nhập lại trước khi đổi mật khẩu.'
                : 'Không thể đổi mật khẩu: ${error.message ?? error.code}';
          } catch (_) {
            return 'Không thể đổi mật khẩu. Vui lòng thử lại.';
          }
        },
      ),
    );
    if (passwords == null || passwords.isEmpty) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đổi mật khẩu thành công.')),
    );
  }

  // Helper lấy 2 chữ cái đầu làm Avatar (VD: Nguyễn Hoàng Minh -> MN)
  String _getInitials(String name) {
    List<String> words = name.trim().split(' ');
    if (words.length >= 2) {
      return (words[words.length - 2][0] + words[words.length - 1][0])
          .toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : "U";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Cá nhân',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {
              // Đi tới cài đặt ứng dụng
            },
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ==========================================
              // 1. ẢNH ĐẠI DIỆN CHỮ VIẾT TẮT & HỌ TÊN, EMAIL
              // ==========================================
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // Màu xanh nhạt
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFDBEAFE),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(_fullName),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB), // Xanh lam thương hiệu
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _joinDate,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ==========================================
              // 2. KHỐI THỐNG KÊ CHỈ SỐ (STATS GRID BANNER)
              // ==========================================
              Row(
                children: [
                  _buildStatItem(
                    '$_examsTaken',
                    'Đề đã làm',
                    const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 10),
                  _buildStatItem(
                    _avgScore.toStringAsFixed(1),
                    'Điểm TB',
                    const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 10),
                  _buildStatItem(
                    '$_streakDays',
                    'Ngày liên tiếp',
                    const Color(0xFFA855F7),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ==========================================
              // 3. DANH SÁCH MENU ĐIỀU HƯỚNG/HÀNH ĐỘNG
              // ==========================================
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Sửa họ tên
                    _buildMenuItem(
                      icon: Icons.person_outline_rounded,
                      title: 'Chỉnh sửa họ tên',
                      subtitle: 'Cập nhật tên hiển thị',
                      iconColor: const Color(0xFF2563EB),
                      onTap: _changeDisplayName,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Đổi mật khẩu
                    _buildMenuItem(
                      icon: Icons.lock_outline_rounded,
                      title: 'Đổi mật khẩu',
                      subtitle: 'Bảo vệ tài khoản của bạn',
                      iconColor: const Color(0xFF2563EB),
                      onTap: _changePassword,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),

                    // Đăng xuất
                    _buildMenuItem(
                      icon: Icons.logout_rounded,
                      title: 'Đăng xuất',
                      subtitle: 'Thoát khỏi Smart Quiz trên thiết bị này',
                      iconColor: const Color(0xFFEF4444),
                      onTap: _handleSignOut,
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Widget con xây dựng khung chỉ số đơn lẻ
  Widget _buildStatItem(String value, String label, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget con xây dựng Item menu
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDestructive ? const Color(0xFFEF4444) : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDestructive ? const Color(0xFFEF4444) : Colors.grey.shade400,
          size: 18,
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final Future<String?> Function(String oldPassword, String newPassword)
  onSubmit;

  const _ChangePasswordDialog({required this.onSubmit});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorMessage;

  bool _isSubmitting = false;

  Future<void> _submit() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    if (oldPassword.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mật khẩu hiện tại.');
    } else if (newPassword.length < 6) {
      setState(() => _errorMessage = 'Mật khẩu tối thiểu 6 ký tự.');
    } else if (newPassword != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Mật khẩu nhập lại không khớp.');
    } else {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });
      final error = await widget.onSubmit(oldPassword, newPassword);
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = error;
        });
        return;
      }
      Navigator.of(context).pop([oldPassword, newPassword]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _oldPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
          ),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
          ),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Nhập lại mật khẩu'),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Cập nhật'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
