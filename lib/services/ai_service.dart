import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AIService {
  static Future<String> explainQuestion({
    required String questionContent,
    required List<String> options,
    required String correctAnswer,
  }) async {
    // 1. Đọc API Key
    final env = dotenv.isInitialized ? dotenv.env : const <String, String>{};
    var apiKey = env['AI_API_KEY']?.trim() ?? '';
    if (apiKey.isEmpty) {
      apiKey = const String.fromEnvironment('AI_API_KEY').trim();
    }
    if (apiKey.isEmpty) {
      throw StateError(
        'Chưa cấu hình AI_API_KEY. Hãy kiểm tra file .env hoặc --dart-define.',
      );
    }

    // 2. Ưu tiên mô hình gemini-1.5-flash vì quota miễn phí cao nhất và rất ít khi lỗi
    var customModel = env['GEMINI_MODEL']?.trim() ?? '';
    final candidateModels = [
      if (customModel.isNotEmpty) customModel,
      'gemini-1.5-flash',
      'gemini-3.5-flash-lite',
      'gemini-3.8-flash',
    ];

    http.Response? lastResponse;
    String lastErrorMessage = '';

    // 3. Vòng lặp thử qua các mô hình
    for (final modelName in candidateModels) {
      final uri = Uri.https(
        'generativelanguage.googleapis.com',
        '/v1beta/models/$modelName:generateContent',
        {'key': apiKey},
      );

      try {
        final response = await http
            .post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {
                        'text':
                            'Giải thích ngắn gọn bằng tiếng Việt vì sao đáp án '
                            'đúng cho câu hỏi trắc nghiệm sau. Không suy đoán nếu dữ '
                            'liệu chưa đủ.\n'
                            'Câu hỏi: $questionContent\n'
                            'Các lựa chọn: ${options.asMap().entries.map((entry) => '${entry.key + 1}. ${entry.value}').join('\n')}\n'
                            'Đáp án đúng: $correctAnswer',
                      },
                    ],
                  },
                ],
              }),
            )
            .timeout(const Duration(seconds: 8));

        lastResponse = response;

        // Nếu thành công (200-299), ngắt vòng lặp ngay
        if (response.statusCode >= 200 && response.statusCode < 300) {
          break;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['error'] != null) {
          lastErrorMessage = decoded['error']['message'] ?? response.body;
        } else {
          lastErrorMessage = response.body;
        }

        // Nếu lỗi 404, 429 (hết quota) hoặc 503 (bận) -> Nhảy sang mô hình tiếp theo ngay
        if (response.statusCode == 404 ||
            response.statusCode == 429 ||
            response.statusCode == 503) {
          continue;
        }
        break;
      } catch (e) {
        lastErrorMessage = e.toString();
        continue;
      }
    }

    // 4. Bắt lỗi HTTP cuối cùng
    if (lastResponse == null ||
        lastResponse.statusCode < 200 ||
        lastResponse.statusCode >= 300) {
      if (lastResponse?.statusCode == 429) {
        throw Exception(
          'Đã vượt quá giới hạn lượt gọi miễn phí hôm nay. Vui lòng thử lại sau ít phút!',
        );
      }
      throw Exception(
        'Dịch vụ AI trả về HTTP ${lastResponse?.statusCode}: $lastErrorMessage',
      );
    }

    // 5. Trích xuất nội dung giải thích
    final decoded = jsonDecode(lastResponse.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Phản hồi AI không đúng định dạng.');
    }
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const FormatException('Dịch vụ AI không trả về nội dung.');
    }
    final firstCandidate = candidates.first;
    if (firstCandidate is! Map<String, dynamic>) {
      throw const FormatException('Phản hồi AI không đúng định dạng.');
    }
    final content = firstCandidate['content'];
    if (content is! Map<String, dynamic>) {
      throw const FormatException('Phản hồi AI không có nội dung.');
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const FormatException('Phản hồi AI không có phần giải thích.');
    }
    final firstPart = parts.first;
    if (firstPart is! Map<String, dynamic>) {
      throw const FormatException('Phản hồi AI không đúng định dạng.');
    }
    final text = firstPart['text'];
    if (text is! String || text.trim().isEmpty) {
      throw const FormatException('Phản hồi AI không có nội dung giải thích.');
    }
    return text.trim();
  }
}