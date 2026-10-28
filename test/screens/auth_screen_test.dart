import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:laptrinhdidong/screens/auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupFirebaseCoreMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
  });

  Widget createAuthScreen() {
    return const MaterialApp(home: AuthScreen());
  }

  group('AuthScreen Widget Tests', () {
    testWidgets('Hiển thị đầy đủ giao diện Đăng nhập mặc định', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createAuthScreen());
      await tester.pumpAndSettle();

      // Kiểm tra Logo và tiêu đề
      expect(find.text('Smart Quiz'), findsOneWidget);
      expect(
        find.text('Học đúng trọng tâm, tiến bộ mỗi ngày.'),
        findsOneWidget,
      );

      // Kiểm tra các trường nhập liệu mặc định ở màn Đăng nhập
      expect(find.text('Tài khoản Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);

      // Không hiển thị trường Họ và tên khi ở tab Đăng nhập
      expect(find.text('Họ và tên'), findsNothing);
      expect(find.text('Xác nhận mật khẩu'), findsNothing);
    });

    testWidgets(
      'Chuyển sang tab Đăng ký hiển thị thêm trường Họ tên và Xác nhận mật khẩu',
      (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        await tester.pumpAndSettle();

        // Nhấn vào tab "Đăng ký"
        await tester.tap(find.text('Đăng ký'));
        await tester.pumpAndSettle();

        // Kiểm tra giao diện chuyển sang form Đăng ký
        expect(find.text('Họ và tên'), findsOneWidget);
        expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
        expect(find.text('Tạo tài khoản'), findsOneWidget);

        // Nút Quên mật khẩu sẽ bị ẩn ở tab Đăng ký
        expect(find.text('Quên mật khẩu?'), findsNothing);
      },
    );

    testWidgets(
      'Báo lỗi validate khi bấm Đăng nhập mà để trống email, mật khẩu',
      (WidgetTester tester) async {
        await tester.pumpWidget(createAuthScreen());
        await tester.pumpAndSettle();

        // Nhấn nút Đăng nhập khi chưa nhập dữ liệu
        await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
        await tester.pump();

        // Hiển thị thông báo lỗi
        expect(find.text('Email không hợp lệ'), findsOneWidget);
        expect(find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
      },
    );
  });
}
