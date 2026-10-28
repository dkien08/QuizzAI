import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:laptrinhdidong/screens/profile_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  Widget createProfileScreen() {
    return const MaterialApp(
      home: ProfileScreen(),
    );
  }

  group('ProfileScreen Widget Tests', () {
    testWidgets('Hiển thị đầy đủ giao diện cá nhân và các mục chức năng', (WidgetTester tester) async {
      await tester.pumpWidget(createProfileScreen());
      await tester.pumpAndSettle();

      // Kiểm tra AppBar
      expect(find.text('Cá nhân'), findsOneWidget);

      // Kiểm tra khối thống kê
      expect(find.text('Đề đã làm'), findsOneWidget);
      expect(find.text('Điểm TB'), findsOneWidget);
      expect(find.text('Ngày liên tiếp'), findsOneWidget);

      // Kiểm tra danh sách chức năng chỉnh sửa
      expect(find.text('Chỉnh sửa họ tên'), findsOneWidget);
      expect(find.text('Đổi mật khẩu'), findsOneWidget);
      expect(find.text('Đăng xuất'), findsOneWidget);
    });

    testWidgets('Bấm vào Đăng xuất hiện dialog xác nhận', (WidgetTester tester) async {
      await tester.pumpWidget(createProfileScreen());
      await tester.pumpAndSettle();

      // Kéo màn hình tới tùy chọn Đăng xuất
      final logoutFinder = find.text('Đăng xuất').first;
      await tester.dragUntilVisible(
        logoutFinder,
        find.byType(SingleChildScrollView),
        const Offset(0, -100),
      );

      // Bấm vào tùy chọn Đăng xuất
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      // Kiểm tra AlertDialog xuất hiện
      expect(
        find.text('Bạn có chắc chắn muốn thoát khỏi Smart Quiz trên thiết bị này?'),
        findsOneWidget,
      );
      expect(find.text('Hủy'), findsOneWidget);
    });
  });
}