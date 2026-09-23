import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Thay bằng domain Render của bạn
  static const String baseUrl = 'https://quizzapp-kovj.onrender.com';

  // 1. Lưu JWT Token vào bộ nhớ máy
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  // 2. Lấy Token đã lưu
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // 3. API Đăng nhập
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = data['access_token'] ?? data['token'];
      if (token != null) {
        await saveToken(token);
      }
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Đăng nhập thất bại'};
    }
  }

  // 4. API Lấy danh sách đề thi (khớp với bảng exams vừa tạo)
  static Future<List<dynamic>> getExams() async {
    final url = Uri.parse('$baseUrl/exams');
    final token = await getToken();

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Không thể tải danh sách đề thi');
    }
  }
}