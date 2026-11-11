# Đưa EduQuest lên Supabase và build APK

Bản này dùng **một dự án Supabase**. Sau khi thiết lập, APK gọi Supabase qua Internet. Máy tính chỉ cần cho bước triển khai và build.

## 1. Tạo hoặc chọn dự án Supabase

1. Vào [Supabase Dashboard](https://supabase.com/dashboard) và tạo một dự án, hoặc chọn dự án bạn dành cho EduQuest. Lấy **Project ref** từ URL Dashboard và lấy **Project URL** cùng **Publishable key** từ **Connect** hoặc **Settings → API Keys**.
2. Trong **Authentication → Providers → Email**, kiểm tra Email đã bật. App hỗ trợ xác nhận email. Nếu dự án yêu cầu xác nhận, người đăng ký mở email rồi quay lại app để đăng nhập. Kiểm tra cấu hình gửi email của dự án trước khi mời nhiều người dùng.
3. Có thể kiểm tra phần **Integrations → Cron**. Migration sẽ bật `pg_cron` nếu cần và tạo các lịch chạy cho EduQuest.

## 2. Đưa cơ sở dữ liệu và hàm tải tài liệu lên Supabase

Cài [Node.js và Supabase CLI qua npx](https://supabase.com/docs/guides/local-development/cli/getting-started). Mở PowerShell trong thư mục gốc đã giải nén, nơi có thư mục `supabase`, rồi chạy:

```powershell
npx supabase login
npx supabase link --project-ref PROJECT_REF
npx supabase db push --remote
npx supabase functions deploy eduquest-upload --project-ref PROJECT_REF --use-api
```

Thay `PROJECT_REF` bằng mã thật. Khi CLI hỏi mật khẩu PostgreSQL, nhập mật khẩu dự án trên máy của bạn. Bước deploy Edge Function qua API chạy được từ CLI với `--use-api`. [Tài liệu deploy Edge Functions](https://supabase.com/docs/guides/functions/deploy)

Kiểm tra trong Dashboard:

- **Database** có schema `eduquest_app` và bảng `public.eduquest_room_updates` trong publication `supabase_realtime`. Bật Data API nếu dự án đang tắt tính năng này. Giữ `public` trong danh sách schema được API truy cập và giữ `eduquest_app` ở chế độ riêng.
- **Storage** có bucket riêng tư `eduquest-documents`, do migration tạo.
- **Edge Functions** có `eduquest-upload`. Hàm tự kiểm tra token người dùng qua Supabase Auth trước khi đọc hoặc sửa dữ liệu. Hàm dùng khóa máy chủ từ biến môi trường do Supabase cấp.
- **Integrations → Cron** có job `eduquest-advance-rooms` và `eduquest-cron-history-cleanup`. Job đầu kiểm tra các lượt hết giờ mỗi hai giây. Khi người chơi đang mở phòng, RPC cũng cập nhật lượt đã hết hạn.

Mã nguồn chưa chứa dữ liệu tài khoản, lịch sử hay tài liệu của máy chủ cũ. Migration tạo ba bài mẫu. Tài khoản đang nằm trong backend .NET/SQLite cũ cần đăng ký lại hoặc được chuyển dữ liệu riêng. Dữ liệu ở schema `eduquest` cũ, nếu có trong cùng dự án, được giữ riêng.

## 3. Build APK trong Android Studio

Mở thư mục `flutter_app` trong Android Studio. Cần Flutter 3.44 trở lên và Android SDK Platform 36. Dùng **Project URL** dạng `https://PROJECT_REF.supabase.co` và **Publishable key** dạng `sb_publishable_…`. Với dự án dùng khóa cũ, khóa `anon` cũng dùng được. Giữ database password, secret key và service role ở phía máy chủ.

Từ Terminal trong Android Studio, ở thư mục `flutter_app`:

```powershell
flutter pub get
flutter build apk --release --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Thay hai giá trị mẫu bằng thông tin dự án. APK ở `build/app/outputs/flutter-apk/app-release.apk`. Để chạy thử từ cấu hình Run của Android Studio, thêm hai tham số `--dart-define` tương tự vào **Additional run args**.

Nếu định gửi bản cập nhật, dùng cùng một khóa ký cho mọi bản. Tạo keystore một lần trong `flutter_app/android` rồi tạo file `key.properties` cùng thư mục với các trường `storeFile`, `storePassword`, `keyAlias` và `keyPassword`. Project đọc cấu hình này khi build. Khi thiếu file đó, build dùng chữ ký debug để thử. [Hướng dẫn ký APK của Flutter](https://docs.flutter.dev/deployment/android)

## 4. Kiểm tra sau khi cài

1. Cài APK trên hai điện thoại, có thể để một máy dùng 4G/5G. Tắt máy tính để kiểm tra ứng dụng dùng Supabase qua mạng.
2. Đăng ký hai tên có dấu. Kiểm tra Trang chủ sau đăng ký, đăng nhập lại và mở lại app.
3. Chọn `samples/mau_cau_hoi.txt` từ bộ nhớ điện thoại, tải lên và kiểm tra số câu nhận được. App lưu TXT, DOCX, XLSX và PDF tối đa 10 MB. Trình đọc PDF dùng lớp văn bản, tối đa 50 trang. File scan cần OCR. Tài liệu không nhận diện được cấu trúc câu hỏi được lưu thành bản nháp. Tệp phức tạp có thể cần chia nhỏ để phù hợp giới hạn xử lý Edge Function.
4. Làm và nộp bài để kiểm tra điểm, lịch sử và hồ sơ. Sau đó tạo phòng trên một máy, vào bằng mã trên máy kia, trả lời và xem xếp hạng.
