import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://quizzapp-kovj.onrender.com';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  // --- 🔥 GENERIC REQUEST METHOD (Chuẩn hóa cho AuthService) ---
  static Future<T> _sendGenericAuthRequest<T>({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    bool requiresAuth = false,
    required T Function(dynamic json) parser,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final token = await getToken();
      if (token == null) throw Exception('Chưa đăng nhập');
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    if (method == 'GET') {
      response = await http.get(url, headers: headers);
    } else if (method == 'POST') {
      response = await http.post(url, headers: headers, body: body != null ? jsonEncode(body) : null);
    } else if (method == 'PUT') {
      response = await http.put(url, headers: headers, body: body != null ? jsonEncode(body) : null);
    } else {
      throw Exception('Phương thức không hợp lệ');
    }

    final decodedData = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parser(decodedData);
    } else {
      throw Exception(decodedData['message'] ?? 'Lỗi yêu cầu xác thực');
    }
  }

  // POST /auth/login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final data = await _sendGenericAuthRequest<Map<String, dynamic>>(
        endpoint: '/auth/login',
        method: 'POST',
        body: {'username': username, 'password': password},
        parser: (json) => json,
      );
      if (data['token'] != null) {
        await saveToken(data['token']);
      }
      return {'success': true, 'data': data};
    } catch (e) {
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // POST /auth/register
  static Future<Map<String, dynamic>> register(String username, String password, String fullName) async {
    try {
      final data = await _sendGenericAuthRequest<Map<String, dynamic>>(
        endpoint: '/auth/register',
        method: 'POST',
        body: {
          'username': username,
          'password': password,
          'full_name': fullName,
          'role': 'users',
        },
        parser: (json) => json,
      );
      return {'success': true, 'message': data['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // GET /users/profile
  static Future<Map<String, dynamic>> getProfile() async {
    return await _sendGenericAuthRequest<Map<String, dynamic>>(
      endpoint: '/users/profile',
      method: 'GET',
      requiresAuth: true,
      parser: (json) => json,
    );
  }

  // PUT /users/profile
  static Future<bool> updateProfile(String fullName) async {
    try {
      await _sendGenericAuthRequest<Map<String, dynamic>>(
        endpoint: '/users/profile',
        method: 'PUT',
        requiresAuth: true,
        body: {'full_name': fullName},
        parser: (json) => json,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // PUT /users/change-password
  static Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    try {
      final data = await _sendGenericAuthRequest<Map<String, dynamic>>(
        endpoint: '/users/change-password',
        method: 'PUT',
        requiresAuth: true,
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
        parser: (json) => json,
      );
      return {'success': true, 'message': data['message'] ?? 'Đổi mật khẩu thành công'};
    } catch (e) {
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }
}