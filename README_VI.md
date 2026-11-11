# EduQuest · Flutter và Supabase

EduQuest là ứng dụng làm bài trắc nghiệm và thi theo phòng. Bản này dùng một dự án Supabase cho đăng nhập, dữ liệu, phòng thi và tài liệu.

- **Flutter** chạy trên điện thoại Android.
- **Supabase Auth** đăng ký, đăng nhập và khôi phục phiên. Tên đăng ký được lưu cùng hồ sơ ngay khi tạo tài khoản.
- **PostgreSQL** lưu hồ sơ, bài thi, lịch sử, phòng và điểm. Các hàm RPC kiểm tra quyền, chấm điểm và giữ đáp án trong schema riêng.
- **Supabase Realtime và Cron** báo thay đổi phòng và chuyển lượt theo giờ máy chủ. App có cơ chế đọc lại trạng thái khi mất kết nối.
- **Supabase Storage và Edge Function** lưu tệp riêng tư và đọc câu hỏi trong TXT, DOCX, XLSX hoặc PDF có lớp văn bản.

Xem [Triển khai Supabase và build APK](TRIEN_KHAI_VA_BUILD_APK.md). File mẫu để tải thử nằm tại [samples/mau_cau_hoi.txt](samples/mau_cau_hoi.txt).
