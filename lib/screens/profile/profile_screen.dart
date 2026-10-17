import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await AuthService.getToken();
    if (token != null) {
      try {
        final profile = await AuthService.getProfile();
        setState(() {
          _isLoggedIn = true;
          _userProfile = profile;
          _isLoading = false;
        });
      } catch (e) {
        await AuthService.logout();
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  // Dialog Đổi họ tên (PUT /users/profile)
  void _showEditNameDialog() {
    final controller = TextEditingController(text: _userProfile?['full_name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chỉnh sửa họ tên'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Họ và tên mới', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final success = await AuthService.updateProfile(newName);
                if (mounted && success) {
                  Navigator.pop(ctx);
                  _checkAuthStatus();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cập nhật họ tên thành công!')),
                  );
                }
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  // Dialog Đổi mật khẩu (PUT /users/change-password)
  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (oldPassController.text.isNotEmpty && newPassController.text.isNotEmpty) {
                final res = await AuthService.changePassword(
                  oldPassController.text.trim(),
                  newPassController.text.trim(),
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message'])),
                  );
                }
              }
            },
            child: const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Nếu chưa có token -> Hiển thị form Đăng nhập/Đăng ký
    if (!_isLoggedIn) {
      return AuthScreen(
        onLoginSuccess: () {
          setState(() => _isLoading = true);
          _checkAuthStatus();
        },
      );
    }

    // Giao diện Profile khi đã đăng nhập
    final fullName = _userProfile?['full_name'] ?? 'Người dùng';
    final username = _userProfile?['username'] ?? 'username';
    final createdAt = _userProfile?['created_at'] != null
        ? _userProfile!['created_at'].toString().split('T').first
        : '2026';

    // Tạo chữ viết tắt Avatar (ví dụ: Nguyễn Hoàng Minh -> NM)
    final words = fullName.trim().split(' ');
    final initials = words.length > 1
        ? '${words.first[0]}${words.last[0]}'.toUpperCase()
        : fullName.substring(0, fullName.length >= 2 ? 2 : 1).toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Cá nhân', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Avatar tròn chữ cái
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBFDBFE), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              fullName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              '@$username',
              style: const TextStyle(fontSize: 15, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text('Tham gia từ $createdAt', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              ],
            ),

            const SizedBox(height: 28),

            // Card chức năng
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.person_outline, color: Color(0xFF2563EB)),
                    ),
                    title: const Text('Chỉnh sửa họ tên', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Cập nhật tên hiển thị', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: _showEditNameDialog,
                  ),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.lock_outline, color: Color(0xFF2563EB)),
                    ),
                    title: const Text('Đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Bảo vệ tài khoản của bạn', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(height: 1, indent: 60),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                    ),
                    title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                    subtitle: const Text('Thoát khỏi Smart Quiz trên thiết bị này', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFFEF4444)),
                    onTap: () async {
                      await AuthService.logout();
                      setState(() {
                        _isLoggedIn = false;
                        _userProfile = null;
                      });
                    },
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