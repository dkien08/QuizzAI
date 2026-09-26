import 'package:flutter/material.dart';

// Import màn hình trang chủ đã có
import 'screens/home_screen.dart';
import 'screens/home/exam_screen.dart';
// Khi từng thành viên hoàn thành các màn hình tiếp theo, mở comment tương ứng:
// import 'screens/practice/practice_screen.dart';
// import 'screens/manage/manage_exams_screen.dart';
// import 'screens/profile/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartQuizApp());
}

class SmartQuizApp extends StatelessWidget {
  const SmartQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Quiz App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF2563EB),
          foregroundColor: Colors.white,
        ),
      ),
      // Màn hình vỏ bọc điều phối 4 Tab và giữ BottomNavigationBar cố định
      home: const MainAppShell(),

      // Hệ thống định tuyến ứng với API Backend
      routes: {
        // Tab 1: Luồng Thi chính thức (GET /exams/code/:code, POST /exams/submit, GET /exams/result/:id)
        '/exam/take': (context) {
       final examData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
       return ExamScreen(examData: examData);
     },
        '/exam/result': (context) => const SubScreenPlaceholder(title: 'Kết quả thi tổng quát'),

        // Tab 2: Luồng Ôn tập & AI (GET /exams/code/:code?mode=practice, POST /exams/check-answer, GET /exams/result-detail/:id, POST /chat/ask)
        '/practice/quiz': (context) => const SubScreenPlaceholder(title: 'Phòng luyện thi tức thì'),
        '/practice/result-detail': (context) => const SubScreenPlaceholder(title: 'Chi tiết đáp án ôn tập'),
        '/practice/chat-ai': (context) => const SubScreenPlaceholder(title: 'Hỏi đáp Trợ lý AI'),

        // Tab 3: Luồng Quản lý đề (GET /exams/my-exams, POST /exams/create, POST /exams/import-excel, GET /exams/:id/stats)
        '/manage/create': (context) => const SubScreenPlaceholder(title: 'Tạo đề thi mới'),
        '/manage/stats': (context) => const SubScreenPlaceholder(title: 'Thống kê & Danh sách điểm'),

        // Tab 4: Xác thực & Cá nhân (POST /auth/login, POST /auth/register, GET/PUT /users/profile, PUT /users/change-password)
        '/auth/login': (context) => const SubScreenPlaceholder(title: 'Đăng nhập'),
        '/auth/register': (context) => const SubScreenPlaceholder(title: 'Đăng ký tài khoản'),
        '/profile/change-password': (context) => const SubScreenPlaceholder(title: 'Đổi mật khẩu'),
      },
    );
  }
}

class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _currentIndex = 0;

  // Danh sách 4 Tab chính
  final List<Widget> _tabs = const [
    HomeScreen(), // Tab 1: Đã gắn trực tiếp màn hình thật kết nối API GET /exams

    TabPlaceholder(
      title: 'Trung Tâm Ôn Tập & AI',
      description: 'Luyện đề phản hồi đáp án tức thì (POST /exams/check-answer), giải thích bằng AI (POST /exams/explain-question) & Xem lại chi tiết (GET /exams/result-detail/:id).',
      icon: Icons.psychology_outlined,
      color: Colors.teal,
    ),
    TabPlaceholder(
      title: 'Quản Lý Đề Thi',
      description: 'Quản lý đề tôi tạo (GET /exams/my-exams), tạo đề thủ công, nhập Excel (POST /exams/import-excel) & Xem thống kê phổ điểm (GET /exams/:id/stats).',
      icon: Icons.folder_shared_outlined,
      color: Colors.indigo,
    ),
    TabPlaceholder(
      title: 'Cá Nhân & Bảo Mật',
      description: 'Hồ sơ người dùng (GET/PUT /users/profile), đổi mật khẩu (PUT /users/change-password) & Đăng nhập/Đăng ký xác thực JWT.',
      icon: Icons.person_outline,
      color: Colors.deepPurple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Thi thật',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Ôn tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Quản lý',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}

// Widget khung tạm thời cho từng Tab
class TabPlaceholder extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const TabPlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget khung tạm thời cho các Route con
class SubScreenPlaceholder extends StatelessWidget {
  final String title;
  const SubScreenPlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Giao diện: $title',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}