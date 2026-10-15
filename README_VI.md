# EduQuest — Flutter + ASP.NET Core REST API + ôn tập đối kháng realtime

Gói này gồm source Flutter, ASP.NET Core 8 Web API, SQLite, trích xuất câu hỏi từ tài liệu và chế độ ôn tập theo từng câu có tính điểm theo tốc độ. Backend là nguồn dữ liệu và nguồn chấm điểm chính thức; không tin điểm do Flutter tự gửi.

## 1. Cài một lần trên Windows

1. Cài **.NET 8 SDK**: https://dotnet.microsoft.com/download/dotnet/8.0
2. Cài **Flutter SDK** và thêm `flutter\bin` vào PATH: https://docs.flutter.dev/get-started/install/windows/mobile
3. Cài **Android Studio** (Android SDK + Emulator): https://developer.android.com/studio
4. Mở terminal chạy `dotnet --list-sdks` và `flutter doctor`. Khởi động một Android Emulator trong Android Studio, hoặc bật USB debugging trên điện thoại.

## 2. Khởi động

1. Giải nén toàn bộ ZIP vào thư mục bình thường, ví dụ `C:\EduQuest_FullStack`.
2. Mở Android Emulator.
3. Nhấp đúp `RUN_ANDROID.bat` ở thư mục gốc. Script mở backend riêng, đợi health check, chạy `flutter pub get`, sau đó chạy app.
4. Giữ cửa sổ `EduQuest API` mở trong khi sử dụng. Swagger: http://localhost:5080/swagger

Dùng điện thoại Android thật: máy tính và điện thoại phải cùng Wi-Fi, bật USB debugging, sau đó chạy `RUN_ANDROID_PHONE.bat`. Nếu Windows Firewall hỏi, cho phép kết nối trên mạng Private. Muốn chạy API riêng thì nhấp đúp `backend\RUN_API.bat`.

Lần đầu cần Internet để tải các package NuGet/Flutter. Script không thể cài tự động SDK nền tảng; các SDK này phải được cài trước.

## 3. Cách ôn tập đối kháng hoạt động

- Chủ phòng chọn bài có câu hỏi, tạo mã phòng và đặt thời gian mỗi câu **20–30 giây** (mặc định 25 giây).
- Người chơi vào phòng bằng mã. Chủ phòng bắt đầu trận khi mọi người đã vào.
- Server phát cùng một câu hỏi và các phương án cho tất cả người chơi. **Không phát đáp án đúng hay điểm câu hiện tại trong giai đoạn trả lời.**
- Mỗi người chơi chỉ được chốt **một đáp án cho mỗi câu**. Server kiểm tra thời gian nhận đáp án và lưu đáp án vào SQLite; gửi tiến độ số người đã trả lời nhưng không tiết lộ ai đúng, điểm hoặc thứ hạng mới.
- Khi hết giờ, server công bố đáp án đúng, giải thích (nếu có), điểm câu của từng người và bảng xếp hạng tổng. Đúng càng sớm thì càng nhiều điểm: tối đa 1.000 điểm lúc gần đầu câu và giảm dần đến tối thiểu 100 điểm nếu vẫn trả lời đúng trước khi hết giờ; sai hoặc bỏ qua được 0 điểm.
- Bảng kết quả hiển thị 5 giây rồi server tự chuyển sang câu kế tiếp. Sau câu cuối, công bố bảng xếp hạng cuối.
- Đồng hồ và chuyển câu chạy ở backend, không phụ thuộc một người chơi giữ ứng dụng mở. SignalR đẩy sự kiện realtime; Flutter tự đồng bộ trạng thái qua REST nếu realtime tạm mất kết nối.

Các API realtime chính: `/hubs/rooms` với sự kiện `QuestionStarted`, `RoundProgress`, `QuestionResult`, `GameFinished`, `RoomUpdated`. API REST dự phòng: `GET /api/rooms/{id}/game-state`, `POST /api/rooms/{id}/answers`.

## 4. Trích xuất câu hỏi từ file

Upload hỗ trợ `.txt`, `.docx`, `.xlsx` và PDF có lớp văn bản, tối đa 10 MB. File được lưu trong `backend\uploads`; metadata và bài thi được lưu trong SQLite. Sau khi phân tích, API trả số câu hỏi tạo được và cảnh báo để người dùng rà soát.

### Cách chắc chắn nhất: dùng mẫu định dạng

Có file mẫu ở `samples\mau_cau_hoi.txt`. Mỗi câu theo cấu trúc:

```text
Câu 1: Flutter được phát triển bởi công ty nào?
A. Microsoft
B. Google
C. Apple
D. Meta
Đáp án: B
Giải thích: Flutter là bộ công cụ giao diện do Google phát triển.
```

Có thể dùng `Question 1:` và `Correct answer: B` bằng tiếng Anh. Phương án cần nằm trên các dòng riêng, nhãn A–E, và đáp án đúng phải ghi rõ bằng chữ cái. Khi cấu trúc câu hỏi rõ ràng, parser tạo các câu hỏi có đáp án theo thứ tự phương án.

### File XLSX

Parser đọc sheet đầu tiên. Dòng đầu phải là tiêu đề cột; các cột đề xuất: `Câu hỏi`, `A`, `B`, `C`, `D`, `Đáp án`, `Giải thích`. Cột đáp án cần chứa chữ cái như `B`, không phải nội dung phương án.

### Tài liệu ghi chú chưa có câu hỏi

Nếu tài liệu chứa các dòng định nghĩa có cấu trúc như `Khái niệm là ...`, hệ thống có thể tạo câu hỏi khái niệm–định nghĩa với phương án gây nhiễu lấy từ những định nghĩa khác trong cùng tài liệu. Các câu dạng này luôn có cảnh báo cần rà soát. Nếu parser không xác định được đáp án chắc chắn, file vẫn được lưu nhưng bài thi là bản nháp và **không thể dùng để tạo phòng** cho đến khi có câu hỏi/đáp án hợp lệ.

**Giới hạn có chủ đích:** PDF scan/chụp ảnh không có lớp văn bản cần OCR trước khi upload. Parser không tự bịa đáp án, không coi việc đọc được văn bản là đã hiểu đúng nội dung, và khuyến nghị kiểm tra câu hỏi/đáp án trích xuất trước khi dùng cho kỳ ôn tập.

## 5. Dữ liệu và tài khoản

- Database: `backend\eduquest.db`, được tạo khi chạy API lần đầu. Bản cập nhật có bước bổ sung các cột/trạng thái phòng mới cho database cũ; vẫn nên sao lưu database trước khi nâng cấp.
- File upload: `backend\uploads`.
- Flutter tự tạo một tài khoản riêng cho mỗi bản cài, lưu ID cục bộ để đăng nhập lại. Đổi tên trong hồ sơ để bạn bè dễ nhận ra. UI gốc chưa có màn hình đăng nhập bằng email/mật khẩu.
- Tài khoản demo dùng thử qua Swagger: `student@eduquest.local` / `Student@123`.

## 6. Khi gặp lỗi

- `Không kết nối được EduQuest API`: kiểm tra cửa sổ API và cổng 5080. Android Emulator sử dụng `http://10.0.2.2:5080`; điện thoại thật sử dụng `RUN_ANDROID_PHONE.bat` và cần cùng mạng Wi-Fi.
- `dotnet restore` lỗi: kiểm tra cài .NET 8 SDK và kết nối Internet.
- `flutter pub get` lỗi: kiểm tra Flutter SDK/PATH và mạng.
- Không tạo được phòng: bài thi cần có ít nhất một câu hỏi với tối thiểu hai phương án và đáp án hợp lệ.
- Không nhận câu hỏi từ tài liệu: kiểm tra định dạng mẫu và cảnh báo trả về khi upload; file scan cần OCR trước.

## 7. Phạm vi triển khai

Gói này dành cho môi trường phát triển/đồ án local. Trước khi public Internet cần đổi JWT key, cấu hình HTTPS/CORS, bảo vệ upload, thêm rate limit và triển khai backup cho SQLite. Vì môi trường tạo gói không có Flutter/.NET SDK, source chưa được build end-to-end tại đây; lần chạy đầu trên máy có SDK là bước xác nhận biên dịch cần thiết.
