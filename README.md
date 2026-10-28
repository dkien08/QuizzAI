# Smart Quiz

Ứng dụng luyện tập và quản lý bài thi trắc nghiệm được xây dựng bằng
Flutter. Người dùng có thể đăng ký tài khoản, tham gia đề thi công khai hoặc
đề thi bằng mã phòng, tự tạo đề, theo dõi thống kê và nhờ AI giải thích đáp án.

## Tính năng

- Đăng ký, đăng nhập, đăng xuất và đặt lại mật khẩu bằng Firebase
  Authentication.
- Trang chủ:
  - Xem các đề thi công khai và đề thi do mình tạo.
  - Lọc đề theo danh mục.
  - Tham gia đề bằng mã phòng.
  - Nhập mật khẩu khi truy cập đề riêng tư.
- Làm bài trắc nghiệm với thời gian giới hạn và chế độ luyện tập.
- Quản lý đề thi cá nhân:
  - Tạo, chỉnh sửa và xóa đề.
  - Đặt tiêu đề, danh mục, thời lượng, trạng thái công khai/riêng tư và
    quyền cho phép luyện tập.
  - Tìm kiếm theo tên, danh mục hoặc mã đề.
  - Xem thống kê đề thi.
- Nhập danh sách câu hỏi từ file Excel `.xlsx`.
- Lưu dữ liệu theo thời gian thực trên Cloud Firestore.
- Hồ sơ cá nhân và cập nhật thông tin người dùng.
- AI giải thích câu hỏi trắc nghiệm bằng Google Gemini API (tùy chọn).

## Công nghệ sử dụng

| Thành phần | Công nghệ |
| --- | --- |
| Giao diện | Flutter, Dart |
| Xác thực | Firebase Authentication |
| Cơ sở dữ liệu | Cloud Firestore |
| AI | Google Gemini API |
| Lưu cấu hình cục bộ | `flutter_dotenv` |
| Nhập dữ liệu | `file_picker`, `excel` |
| HTTP và tiện ích | `http`, `shared_preferences` |

## Yêu cầu môi trường

- Flutter SDK tương thích với Dart SDK `^3.13.1`.
- Android Studio hoặc Xcode nếu chạy trên thiết bị di động.
- Một dự án Firebase đã bật:
  - Firebase Authentication với phương thức Email/Password.
  - Cloud Firestore.
- API key của Google Gemini nếu muốn sử dụng chức năng giải thích bằng AI.

## Cài đặt

1. Clone repository và đi vào thư mục dự án:

   ```bash
   git clone https://github.com/dkien08/QuizzAI.git
   cd QuizzAI
   ```

2. Cài dependency:

   ```bash
   flutter pub get
   ```

3. Cấu hình Firebase:

   - Tạo hoặc chọn một Firebase project.
   - Cấu hình ứng dụng Android/iOS/Web tương ứng với nền tảng cần chạy.
   - Đảm bảo file cấu hình Firebase được tạo tại `lib/firebase_options.dart`.
   - Với Android, kiểm tra thêm file `android/app/google-services.json` nếu
     dự án Firebase của bạn yêu cầu file này.
   - Triển khai rules Firestore trong [firestore.rules](./firestore.rules).

4. Tạo file `.env` từ file mẫu:

   ```bash
   copy .env.example .env
   ```

   Trên macOS/Linux có thể dùng:

   ```bash
   cp .env.example .env
   ```

   Sau đó điền API key Gemini:

   ```dotenv
   AI_API_KEY=your_gemini_api_key
   GEMINI_MODEL=gemini-2.5-flash
   ```

   Nếu không cấu hình `AI_API_KEY`, các chức năng chính của ứng dụng vẫn có
   thể hoạt động nhưng tính năng giải thích bằng AI sẽ thông báo chưa được
   cấu hình.

5. Chạy ứng dụng:

   ```bash
   flutter run
   ```

   Chọn thiết bị bằng `flutter devices` hoặc chạy trực tiếp trên Chrome:

   ```bash
   flutter run -d chrome
   ```

## Định dạng file Excel

Khi nhập câu hỏi, ứng dụng đọc sheet đầu tiên và bỏ qua dòng tiêu đề. Mỗi
dòng dữ liệu nên có các cột theo thứ tự:

| Cột | Nội dung |
| --- | --- |
| A | Nội dung câu hỏi |
| B | Đáp án A |
| C | Đáp án B |
| D | Đáp án C |
| E | Đáp án D |
| F | Đáp án đúng: `A`/`B`/`C`/`D` hoặc `1`/`2`/`3`/`4` |

Ví dụ:

| Câu hỏi | A | B | C | D | Đáp án đúng |
| --- | --- | --- | --- | --- | --- |
| Flutter dùng ngôn ngữ nào? | Java | Dart | Kotlin | Swift | B |

## Cấu trúc thư mục

```text
lib/
├── main.dart                  # Điểm khởi chạy và điều hướng chính
├── firebase_options.dart      # Cấu hình Firebase theo nền tảng
├── models/                    # Model người dùng, đề thi và model cơ sở
├── services/
│   ├── auth_service.dart      # Đăng ký, đăng nhập, đăng xuất, đặt lại mật khẩu
│   ├── firebase_repository.dart # Đọc/ghi dữ liệu Firestore dùng chung
│   ├── ai_service.dart        # Gọi Google Gemini API
│   └── excel_service.dart     # Đọc câu hỏi từ file Excel
├── screens/                   # Các màn hình xác thực, làm bài và quản lý
├── widgets/                   # Widget giao diện dùng chung
└── utils/                     # Tiện ích và dữ liệu khởi tạo
```

## Mô hình dữ liệu Firestore

Ứng dụng sử dụng các collection chính:

- `users`: thông tin tài khoản, vai trò và chuỗi ngày học.
- `exams`: thông tin đề thi, mã đề, quyền truy cập và tác giả.
- `exams/{examId}/questions`: các câu hỏi thuộc một đề thi.
- `exam_sessions`: phiên làm bài đang hoạt động hoặc đã kết thúc.
- `exam_submissions`: bài nộp và kết quả của người dùng.

Rules trong [firestore.rules](./firestore.rules) giới hạn quyền đọc/ghi theo
người dùng đăng nhập và chủ sở hữu đề thi. Khi thay đổi cấu trúc dữ liệu,
cần cập nhật rules tương ứng trước khi triển khai.

## Kiểm tra chất lượng

Chạy phân tích tĩnh và test Flutter:

```bash
flutter analyze
flutter test
```

Định dạng mã nguồn:

```bash
dart format lib
```

## Build

Build Android APK:

```bash
flutter build apk --release
```

Build bản web:

```bash
flutter build web --release
```

## Bảo mật

- Không commit file `.env` hoặc API key vào repository.
- Chỉ commit `.env.example` với giá trị mẫu.
- Không nới lỏng `firestore.rules` thành `allow read, write: if true`.
- Khi phát hành production, nên dùng biến môi trường hoặc cơ chế quản lý
  secret phù hợp với từng nền tảng.

