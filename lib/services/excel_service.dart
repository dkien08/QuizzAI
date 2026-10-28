import 'dart:io';

import 'package:flutter/foundation.dart'; // Thêm để dùng kIsWeb
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

class ExcelService {
  static int _parseCorrectIndex(dynamic value) {
    final answer = value?.toString().trim().toUpperCase() ?? '';
    const labels = {'A': 0, 'B': 1, 'C': 2, 'D': 3};
    if (labels.containsKey(answer)) return labels[answer]!;

    final numericAnswer = int.tryParse(answer);
    if (numericAnswer == null) return -1;
    if (numericAnswer >= 1 && numericAnswer <= 4) return numericAnswer - 1;
    return numericAnswer;
  }

  /// Hàm chọn file Excel từ thiết bị và bóc tách thành danh sách Map câu hỏi
  /// Tương thích 100% trên cả Web, Android và iOS
  static Future<List<Map<String, dynamic>>?> importQuestionsFromExcel() async {
    try {
      // 1. Cho phép người dùng chọn file .xlsx
      // Lưu ý: Đặt withData: true để luôn lấy được dữ liệu 'bytes' trên Web
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return null;

      PlatformFile file = result.files.single;
      List<int>? bytes;

      // 2. Xử lý đọc Bytes tương thích đa nền tảng
      if (kIsWeb) {
        // Trên môi trường Web: Đọc trực tiếp từ thuộc tính bytes
        bytes = file.bytes;
      } else {
        // Trên Mobile / Desktop: Nếu bytes null thì đọc từ File path
        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = File(file.path!).readAsBytesSync();
        }
      }

      if (bytes == null) return null;

      // 3. Giải mã file Excel từ mảng Bytes
      var excel = Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> questions = [];

      // 4. Bóc tách dữ liệu từ Sheet đầu tiên trong file Excel
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // Bỏ qua dòng tiêu đề (Header ở index 0)
        for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
          var row = sheet.rows[rowIndex];
          if (row.isEmpty || row[0] == null) continue;

          String questionText = row[0]?.value.toString().trim() ?? '';
          String optA = row.length > 1
              ? row[1]?.value.toString().trim() ?? ''
              : '';
          String optB = row.length > 2
              ? row[2]?.value.toString().trim() ?? ''
              : '';
          String optC = row.length > 3
              ? row[3]?.value.toString().trim() ?? ''
              : '';
          String optD = row.length > 4
              ? row[4]?.value.toString().trim() ?? ''
              : '';
          int correctIndex = row.length > 5
              ? _parseCorrectIndex(row[5]?.value)
              : -1;

          if (questionText.isNotEmpty) {
            questions.add({
              'content': questionText,
              'options': [optA, optB, optC, optD],
              'correctAnswerIndex': correctIndex,
            });
          }
        }
        break; // Chỉ bóc tách 1 sheet chính
      }

      return questions;
    } catch (e) {
      debugPrint("Lỗi đọc file Excel: $e");
      rethrow;
    }
  }
}
