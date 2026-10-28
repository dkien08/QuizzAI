import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedExamsToFirebase() async {
  final CollectionReference examsCollection = FirebaseFirestore.instance
      .collection('exams');

  // Danh sách các đề thi mẫu
  final List<Map<String, dynamic>> sampleExams = [
    {
      'title': 'Ôn thi THPT — Hàm số & Đạo hàm',
      'categoryTag': 'TOÁN',
      'totalQuestions': 20,
      'durationMinutes': 30,
      'authorName': 'Thầy Nguyễn Minh',
      'isPublic': true,
      'code': 'MATH-2609',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'title': 'Kiểm tra 45 phút — Vật lý 11',
      'categoryTag': 'LÝ',
      'totalQuestions': 25,
      'durationMinutes': 35,
      'authorName': 'CLB Khoa học',
      'isPublic': false,
      'code': 'PHY-1145',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    {
      'title': 'Tiếng Anh 12 — Reading practice',
      'categoryTag': 'ANH',
      'totalQuestions': 30,
      'durationMinutes': 45,
      'authorName': 'Cô Trần Khánh Linh',
      'isPublic': true,
      'code': 'ENG-1208',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    },
  ];

  // Đẩy tự động toàn bộ danh sách lên Firestore
  for (var exam in sampleExams) {
    await examsCollection.add(exam);
  }
  print('-> Đã tự động tạo xong 3 đề thi mẫu trên Firebase!');
}
