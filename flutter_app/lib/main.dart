// lib/main.dart
// Entry point của ứng dụng QuizUp.
// Khởi động app với MultiProvider bao bọc toàn bộ widget tree.

import 'dart:async';
import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/quiz_provider.dart';
import 'providers/upload_provider.dart';
import 'providers/room_provider.dart';
import 'providers/profile_provider.dart';
import 'services/local_database.dart';

Future<void> main() async {
  // Đảm bảo Flutter binding sẵn sàng trước khi chạy app
  WidgetsFlutterBinding.ensureInitialized();

  // Chờ API khởi động và khôi phục phiên đăng nhập đã lưu (nếu có). Nếu API không chạy,
  // màn hình vẫn mở và Provider sẽ hiển thị lỗi thay vì crash ứng dụng.
  try {
    await ApiClient.instance.initialize();
  } catch (_) {
    // Provider thực hiện retry khi gọi endpoint lần đầu.
  }

  try {
    await LocalDatabase.instance.initialize();
  } catch (_) {
    // SQLite local cache không bắt buộc phải hoạt động khi app chưa sẵn sàng.
  }

  runApp(const _SessionRoot());
}

/// Dựng lại toàn bộ Provider mỗi khi đăng nhập/đăng xuất (đổi sessionId)
/// để dữ liệu của tài khoản trước không còn sót lại.
class _SessionRoot extends StatelessWidget {
  const _SessionRoot();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ApiClient.instance.sessionId,
      builder: (context, sessionId, _) {
        return MultiProvider(
          key: ValueKey(sessionId),
          providers: [
            // ProfileProvider: thông tin user, dark mode, settings
            ChangeNotifierProvider(create: (_) => ProfileProvider()),

            // QuizProvider: danh sách quiz, quiz đang làm, kết quả
            ChangeNotifierProvider(create: (_) => QuizProvider()),

            // UploadProvider: state upload file
            ChangeNotifierProvider(create: (_) => UploadProvider()),

            // RoomProvider: phòng thi, join/create room
            ChangeNotifierProvider(create: (_) => RoomProvider()),
          ],
          child: const QuizUpApp(), // Root widget
        );
      },
    );
  }
}
