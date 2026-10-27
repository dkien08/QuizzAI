// lib/models/base_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class BaseModel {
  String get id;
  DateTime get createdAt; // Thời điểm tạo document
  DateTime get updatedAt; // Thời điểm cập nhật gần nhất
  bool get isActive; // Trạng thái (đang kích hoạt hay đã ẩn/xóa mềm)

  // Chuyển Object thành Map/JSON chuẩn để lưu lên Firestore
  Map<String, dynamic> toMap();
}

// Helper giúp parse linh hoạt DateTime từ Firebase Timestamp hoặc String
DateTime parseDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  } else if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  } else if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}
