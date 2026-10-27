import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_model.dart';
import 'firebase_repository.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final userRepo = FirebaseRepository<UserModel>('users', UserModel.fromMap);

  // Lấy User hiện tại từ Firebase Auth
  User? get currentUser => _auth.currentUser;

  // Stream theo dõi trạng thái đăng nhập Realtime
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Đăng ký Tài khoản mới
  Future<UserCredential?> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Tạo UserModel và lưu thông tin vào Firestore Collection 'users'
        UserModel newUser = UserModel(
          id: credential.user!.uid,
          fullName: fullName,
          email: email,
          role: 'student',
          streakDays: 0,
        );

        await userRepo.add(newUser);
      }
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // 2. Đăng nhập
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // 3. Đăng xuất
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
