// lib/main.dart
// Entry point của ứng dụng QuizUp.
// Khởi động app với MultiProvider bao bọc toàn bộ widget tree.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/quiz_provider.dart';
import 'providers/upload_provider.dart';
import 'providers/room_provider.dart';
import 'providers/profile_provider.dart';

void main() {
  // Đảm bảo Flutter binding sẵn sàng trước khi chạy app
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // MultiProvider bọc toàn bộ app để mọi widget có thể access provider
    MultiProvider(
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
    ),
  );
}
