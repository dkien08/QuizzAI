import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../entities/question_entity.dart';
import '../entities/exam_entity.dart';


class ApiService {
  static const String baseUrl = 'https://quizzapp-kovj.onrender.com';

  // --- Quản lý Token ---
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

  // --- 🔥 GENERIC REQUEST METHOD (Tối ưu cốt lõi dùng chung cho các API) ---
  static Future<T> _sendGenericRequest<T>({
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
      if (token == null) throw Exception('Vui lòng đăng nhập để tiếp tục');
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response res;
    if (method == 'GET') {
      res = await http.get(url, headers: headers);
    } else if (method == 'POST') {
      res = await http.post(url, headers: headers, body: body != null ? jsonEncode(body) : null);
    } else if (method == 'PUT') {
      res = await http.put(url, headers: headers, body: body != null ? jsonEncode(body) : null);
    } else {
      throw Exception('HTTP method không hợp lệ');
    }

    final decodedData = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return parser(decodedData);
    } else {
      throw Exception(decodedData['message'] ?? 'Lỗi kết nối server (${res.statusCode})');
    }
  }

  // --- 1. Xác thực (Auth) ---
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final result = await _sendGenericRequest<Map<String, dynamic>>(
        endpoint: '/auth/login',
        method: 'POST',
        body: {'username': username, 'password': password},
        parser: (json) => json,
      );
      if (result['token'] != null) {
        await saveToken(result['token']);
      }
      return {'success': true, 'data': result};
    } catch (e) {
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> register(String username, String password, String fullName) async {
    try {
      final result = await _sendGenericRequest<Map<String, dynamic>>(
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
      return {'success': true, 'message': result['message']};
    } catch (e) {
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  // --- 2. Đề thi công khai (Public Exams) ---
  static Future<List<dynamic>> getPublicExams() async {
    return await _sendGenericRequest<List<dynamic>>(
      endpoint: '/exams',
      method: 'GET',
      parser: (json) => json,
    );
  }

  // Lấy chi tiết đề thi theo mã code
static Future<ExamEntity> getExamByCode(String code, {bool isPractice = false}) async {
  final endpoint = '/exams/code/$code${isPractice ? "?mode=practice" : ""}';
  return await _sendGenericRequest<ExamEntity>(
    endpoint: endpoint,
    method: 'GET',
    parser: (json) => ExamEntity.fromJson(json),
  );
}

  // --- 3. Nộp bài (Cần 🔒 JWT) ---
  static Future<Map<String, dynamic>> submitExam({
    required int examId,
    required List<Map<String, int>> answers,
  }) async {
    return await _sendGenericRequest<Map<String, dynamic>>(
      endpoint: '/exams/submit',
      method: 'POST',
      requiresAuth: true,
      body: {
        'exam_id': examId,
        'answers': answers,
      },
      parser: (json) => json,
    );
  }

  // --- 4. Chatbot AI trợ lý ---
  static Future<String> askChatbot(String message) async {
    final result = await _sendGenericRequest<Map<String, dynamic>>(
      endpoint: '/chat/ask',
      method: 'POST',
      body: {'message': message},
      parser: (json) => json,
    );
    return result['reply'] ?? '';
  }
}