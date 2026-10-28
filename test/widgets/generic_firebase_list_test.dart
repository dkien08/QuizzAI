import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laptrinhdidong/models/user_model.dart';
import 'package:laptrinhdidong/services/firebase_repository.dart';
import 'package:laptrinhdidong/widgets/generic_firebase_list.dart';

// Class MockRepository để giả lập Stream của FirebaseRepository
class MockFirebaseRepository extends Fake implements FirebaseRepository<UserModel> {
  final StreamController<List<UserModel>> _controller = StreamController<List<UserModel>>();

  @override
  Stream<List<UserModel>> getRealtimeList({String? whereField, dynamic whereValue}) {
    return _controller.stream;
  }

  void emitData(List<UserModel> data) => _controller.add(data);
  void emitError(Object error) => _controller.addError(error);
  void close() => _controller.close();
}

void main() {
  late MockFirebaseRepository mockRepo;

  setUp(() {
    mockRepo = MockFirebaseRepository();
  });

  tearDown(() {
    mockRepo.close();
  });

  group('GenericFirebaseList Widget Tests', () {
    testWidgets('Hiển thị CircularProgressIndicator khi đang tải dữ liệu', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericFirebaseList<UserModel>(
              repository: mockRepo,
              itemBuilder: (context, user) => Text(user.fullName),
            ),
          ),
        ),
      );

      // Khi Stream chưa bắn dữ liệu, hiển thị loading icon
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Hiển thị thông báo khi danh sách rỗng', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericFirebaseList<UserModel>(
              repository: mockRepo,
              emptyMessage: 'Chưa có người dùng nào.',
              itemBuilder: (context, user) => Text(user.fullName),
            ),
          ),
        ),
      );

      // Bắn danh sách rỗng
      mockRepo.emitData([]);
      await tester.pump();

      expect(find.text('Chưa có người dùng nào.'), findsOneWidget);
    });

    testWidgets('Hiển thị danh sách item khi Stream trả về dữ liệu thành công', (WidgetTester tester) async {
      final mockUsers = [
        UserModel(id: '1', fullName: 'Nguyễn Văn A', email: 'a@gmail.com', role: 'student'),
        UserModel(id: '2', fullName: 'Trần Thị B', email: 'b@gmail.com', role: 'teacher'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericFirebaseList<UserModel>(
              repository: mockRepo,
              itemBuilder: (context, user) => ListTile(title: Text(user.fullName)),
            ),
          ),
        ),
      );

      // Bắn danh sách dữ liệu
      mockRepo.emitData(mockUsers);
      await tester.pump();

      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Trần Thị B'), findsOneWidget);
    });

    testWidgets('Hiển thị thông báo lỗi khi Stream gặp sự cố', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenericFirebaseList<UserModel>(
              repository: mockRepo,
              itemBuilder: (context, user) => Text(user.fullName),
            ),
          ),
        ),
      );

      // Bắn sự cố lỗi
      mockRepo.emitError('Mất kết nối mạng');
      await tester.pump();

      expect(find.text('Lỗi tải dữ liệu: Mất kết nối mạng'), findsOneWidget);
    });
  });
}