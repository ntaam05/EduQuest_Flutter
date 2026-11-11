# EduQuest

Ứng dụng Flutter hỗ trợ ôn tập trắc nghiệm, quản lý kết quả học tập và thi đấu theo phòng. Dữ liệu được lưu trên Supabase; người dùng đã cài APK chỉ cần điện thoại Android có kết nối Internet để sử dụng.

**Mã nguồn:** [ntaam05/EduQuest_Flutter](https://github.com/ntaam05/EduQuest_Flutter)

## 1. Tải và cài đặt APK

**[Tải APK EduQuest tại đây](https://drive.google.com/drive/folders/1ry2Bdpqn1e9EUKBCP53lISliD2MWtnWY?usp=sharing)**

1. Mở đường dẫn tải bằng điện thoại Android và tải file `.apk`.
2. Mở file vừa tải. Nếu điện thoại yêu cầu, cho phép trình duyệt hoặc trình quản lý tệp cài đặt ứng dụng từ nguồn này.
3. Chọn **Cài đặt**, sau đó mở **EduQuest**.
4. Kết nối Internet, đăng ký tài khoản và đăng nhập để sử dụng.

Sau khi cài đặt, ứng dụng hoạt động độc lập trên điện thoại, không cần cắm dây vào máy tính hay chạy `flutter run`.

## 2. Clone mã nguồn và chạy ứng dụng

### 2.1. Chuẩn bị

- [Git](https://git-scm.com/downloads).
- [Flutter SDK](https://docs.flutter.dev/install), có Dart **từ 3.12.0 đến dưới 4.0.0** theo `flutter_app/pubspec.yaml`.
- [Android Studio và Android SDK](https://docs.flutter.dev/platform-integration/android/setup).
- Máy ảo Android hoặc điện thoại Android đã bật **Tùy chọn nhà phát triển → Gỡ lỗi USB**.
- Kết nối Internet để tải thư viện và truy cập Supabase.

Kiểm tra môi trường trong Terminal hoặc PowerShell:

```sh
flutter --version
flutter doctor
```

Hoàn tất các mục Android toolchain được `flutter doctor` yêu cầu. Khi được yêu cầu chấp nhận giấy phép Android SDK, chạy:

```sh
flutter doctor --android-licenses
```

### 2.2. Clone dự án

Mở Terminal hoặc PowerShell tại thư mục cha muốn lưu dự án, rồi chạy:

```sh
git clone --branch main https://github.com/ntaam05/EduQuest_Flutter.git
cd EduQuest_Flutter/flutter_app
flutter pub get
```

Lệnh `git clone` tạo thư mục `EduQuest_Flutter`. Thư mục ứng dụng cần mở để chạy Flutter là **`EduQuest_Flutter/flutter_app`**, nơi chứa file `pubspec.yaml`.

### 2.3. Kiểm tra kết nối Supabase

Cấu hình kết nối nằm trong [`flutter_app/lib/main.dart`](flutter_app/lib/main.dart):

```dart
const _supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';
const _supabasePublishableKey = 'YOUR_SUPABASE_PUBLISHABLE_KEY';
```

- Dùng backend chung của dự án: giữ cấu hình đã có trong mã nguồn, với điều kiện dự án Supabase đó đang hoạt động.
- Dùng Supabase riêng: tạo backend theo mục 4, sau đó thay hai giá trị trên bằng **Project URL** và **Publishable key** của bạn trong Supabase Dashboard.

Chỉ dùng khóa công khai `sb_publishable_...` hoặc khóa `anon` tương thích trong ứng dụng. Khóa `service_role` hoặc `sb_secret_...` chỉ dùng phía server.

### 2.4. Chạy bằng Terminal

Khởi động máy ảo Android hoặc kết nối điện thoại và chấp nhận yêu cầu gỡ lỗi USB. Tại thư mục `flutter_app`, chạy:

```sh
flutter devices
flutter run
```

Nếu có nhiều thiết bị, chọn thiết bị cụ thể:

```sh
flutter run -d DEVICE_ID
```

Thay `DEVICE_ID` bằng mã thiết bị do `flutter devices` hiển thị.

### 2.5. Chạy bằng Android Studio

1. Cài plugin **Flutter** và **Dart** trong Android Studio nếu chưa có.
2. Chọn **Open**, mở thư mục `EduQuest_Flutter/flutter_app`.
3. Cấu hình đường dẫn Flutter SDK nếu IDE yêu cầu.
4. Chạy `flutter pub get` trong Terminal của IDE.
5. Mở `lib/main.dart`, chọn máy ảo hoặc điện thoại trong danh sách thiết bị.
6. Nhấn **Run ▶** để chạy ứng dụng.

## 3. Các chức năng chính

- Đăng ký, đăng nhập và chỉnh sửa hồ sơ cá nhân.
- Ôn tập trắc nghiệm, xem điểm, đáp án và lịch sử làm bài.
- Tạo bài trắc nghiệm thủ công.
- Tải tài liệu **PDF, DOCX, XLSX, TXT**, tối đa **10 MB**, để trích xuất câu hỏi theo nội dung tài liệu.
- Tạo phòng, tham gia bằng mã phòng và thi đấu với người khác.
- Theo dõi tiến độ, điểm kinh nghiệm và thống kê học tập.

Tài liệu tải lên cần có nội dung văn bản. PDF chỉ chứa ảnh scan chưa được hỗ trợ OCR. Có thể tham khảo định dạng câu hỏi trong [`samples/mau_cau_hoi.txt`](samples/mau_cau_hoi.txt).

## 4. Thiết lập Supabase riêng (tùy chọn)

Mục này dành cho người muốn tự quản lý backend. Người dùng APK và người chạy mã nguồn với backend chung có thể sử dụng cấu hình sẵn của dự án.

### Bước 1: Tạo cơ sở dữ liệu

Tạo một project trên [Supabase](https://supabase.com/dashboard). Mở **SQL Editor**, lần lượt dán và chạy toàn bộ nội dung ba file sau theo đúng thứ tự, mỗi file một lần trên project mới:

1. [`20261108000100_eduquest_data.sql`](supabase/migrations/20261108000100_eduquest_data.sql): dữ liệu học tập, hồ sơ, RPC và bucket tài liệu.
2. [`20261108000200_eduquest_rooms.sql`](supabase/migrations/20261108000200_eduquest_rooms.sql): phòng thi, chấm điểm và Realtime.
3. [`20261108000300_eduquest_schedule.sql`](supabase/migrations/20261108000300_eduquest_schedule.sql): lịch Cron điều phối phòng thi.

### Bước 2: Cấu hình đăng ký, đăng nhập

Trong **Authentication**, bật đăng ký bằng **Email/Password**. Nếu muốn đăng ký xong dùng ngay mà không xác nhận email, tắt **Confirm email**. Nếu bật xác nhận email, người dùng cần xác nhận trước khi đăng nhập.

Ứng dụng sử dụng Supabase Auth để nhận diện tài khoản và phân quyền dữ liệu.

### Bước 3: Triển khai chức năng tải tài liệu

Cài [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started), sau đó mở Terminal tại **thư mục gốc `EduQuest_Flutter`** và chạy:

```sh
supabase login
supabase functions deploy eduquest-upload --project-ref YOUR_PROJECT_REF
```

Thay `YOUR_PROJECT_REF` bằng mã project của bạn. Giữ cấu hình `verify_jwt = false` đã có trong `supabase/config.toml`: hàm `eduquest-upload` tự kiểm tra phiên Supabase Auth của người dùng trước khi xử lý tài liệu.

### Bước 4: Kết nối ứng dụng

Cập nhật `_supabaseUrl` và `_supabasePublishableKey` trong `flutter_app/lib/main.dart` theo mục 2.3, rồi chạy lại ứng dụng. Kiểm tra Cron `eduquest-advance-rooms` đang hoạt động và bảng `public.eduquest_room_updates` đã được thêm vào Realtime theo script.

## 5. Xử lý lỗi thường gặp

| Hiện tượng | Cách xử lý |
| --- | --- |
| Không nhận lệnh `flutter` hoặc `git` | Cài công cụ, thêm vào `PATH`, rồi mở lại Terminal. |
| Không tìm thấy `pubspec.yaml` | Chuyển vào thư mục `EduQuest_Flutter/flutter_app`. |
| Báo phiên bản Dart không phù hợp | Cài Flutter SDK có phiên bản Dart đáp ứng yêu cầu trong `pubspec.yaml`. |
| Không có thiết bị để chạy | Mở máy ảo hoặc bật gỡ lỗi USB trên điện thoại, xác nhận kết nối, rồi chạy lại `flutter devices`. |
| Báo chưa cấu hình Supabase | Kiểm tra URL và Publishable key trong `lib/main.dart`. |
| Đăng nhập chưa được sau khi đăng ký | Kiểm tra email, mật khẩu và yêu cầu xác nhận email của Supabase. |
| Chưa tải được dữ liệu hoặc tài liệu | Kiểm tra Internet, trạng thái project Supabase, các script SQL và hàm `eduquest-upload`. |
| Phòng thi không cập nhật/chuyển câu | Kiểm tra Realtime, job Cron `eduquest-advance-rooms` và kết nối Internet. |

## 6. Thư mục cần biết

| Đường dẫn | Nội dung |
| --- | --- |
| `flutter_app/` | Mã nguồn ứng dụng Flutter; mở thư mục này trong Android Studio. |
| `flutter_app/lib/main.dart` | Điểm khởi chạy và cấu hình Supabase. |
| `supabase/migrations/` | Script SQL khởi tạo backend Supabase. |
| `supabase/functions/eduquest-upload/` | Edge Function xử lý tài liệu tải lên. |
| `samples/` | Tài liệu mẫu để thử nhập câu hỏi. |

Tài liệu tham khảo: [Flutter CLI](https://docs.flutter.dev/reference/flutter-cli) · [Thiết lập Android](https://docs.flutter.dev/platform-integration/android/setup) · [Triển khai Edge Functions](https://supabase.com/docs/guides/functions/deploy).
