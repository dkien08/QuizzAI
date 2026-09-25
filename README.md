```text
lib/
├── firebase_options.dart              # Cấu hình Firebase
├── main.dart                          # Khởi chạy app, cấu hình MaterialApp & Routes
│
├── models/                            # Tầng Model dữ liệu (OOP - Tuần 3)[cite: 4]
│   ├── user.dart                      # Dữ liệu tài khoản & Profile
│   ├── exam.dart                      # Dữ liệu tóm tắt đề thi (Trang chủ)
│   ├── quiz_models.dart               # Dữ liệu chi tiết: Question, Option, ExamDetail
│   └── result_models.dart             # Dữ liệu kết quả thi & thống kê điểm
│
├── services/                          # Tầng gọi API Backend & Bộ nhớ máy
│   ├── auth_service.dart              # Quản lý Token JWT & SharedPreferences
│   ├── api_service.dart               # Các hàm gọi API HTTP (Auth, Exams, Submit, AI)
│   └── exam_service.dart              # Xử lý logic làm bài & nộp bài trắc nghiệm
│
├── screens/                           # Màn hình giao diện (UI / Screens)[cite: 2, 5]
│   ├── auth/                          # Nhóm màn hình Xác thực
│   │   ├── login_screen.dart          # Đăng nhập (/auth/login)
│   │   └── register_screen.dart       # Đăng ký (/auth/register)
│   │
│   ├── home/                          # Nhóm màn hình Trang chủ & Khám phá
│   │   ├── home_screen.dart           # Trang chủ hiển thị danh sách đề thi (/exams)
│   │   └── search_screen.dart         # Tìm kiếm & Nhập mã đề thi (/exams/code/:code)
│   │
│   ├── quiz/                          # Nhóm màn hình Làm bài thi
│   │   ├── exam_screen.dart           # Giao diện thi trắc nghiệm (đồng hồ đếm ngược, chọn câu)
│   │   ├── result_screen.dart         # Màn hình điểm số tổng quát (/exams/result/:id)[cite: 5]
│   │   └── result_detail_screen.dart  # Xem chi tiết đúng/sai từng câu (/exams/result-detail/:id)[cite: 5]
│   │
│   ├── profile/                       # Nhóm màn hình Cá nhân
│   │   ├── profile_screen.dart        # Xem/Đổi thông tin (/users/profile)[cite: 5]
│   │   └── change_password_screen.dart# Đổi mật khẩu (/users/change-password)[cite: 5]
│   │
│   └── chat/                          # Nhóm màn hình Trợ lý AI
│       └── chat_screen.dart           # Khung chat hỏi đáp AI (/chat/ask)[cite: 5]
│
└── widgets/                           # Thành phần giao diện dùng chung (StatelessWidget)[cite: 2, 5]
    ├── custom_drawer.dart             # Menu trượt bên hông (Drawer)[cite: 5]
    ├── exam_card.dart                 # Thẻ hiển thị một đề thi (Trang chủ/Tìm kiếm)
    ├── question_card.dart             # Khung hiển thị câu hỏi và 4 lựa chọn A, B, C, D
    └── ai_explanation_dialog.dart     # Popup giải thích câu hỏi bằng AI (/exams/explain-question)[cite: 5]
```