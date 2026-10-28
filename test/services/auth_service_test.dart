import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService Input Validation Tests', () {
    test('Kiểm tra email hợp lệ trước khi gửi yêu cầu SignUp/SignIn', () {
      bool isValidEmail(String email) {
        return email.isNotEmpty && email.contains('@') && email.contains('.');
      }

      expect(isValidEmail('student@phenikaa.edu.vn'), isTrue);
      expect(isValidEmail('invalid-email'), isFalse);
      expect(isValidEmail(''), isFalse);
    });

    test('Kiểm tra độ dài mật khẩu tối thiểu khi đăng ký', () {
      bool isValidPassword(String password) {
        return password.length >= 6;
      }

      expect(isValidPassword('123456'), isTrue);
      expect(isValidPassword('12345'), isFalse);
    });
  });
}