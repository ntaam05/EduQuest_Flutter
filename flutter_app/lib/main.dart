// lib/main.dart
// Entry point của ứng dụng QuizUp.
// Khởi động app với MultiProvider bao bọc toàn bộ widget tree.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_client.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/quiz_provider.dart';
import 'providers/upload_provider.dart';
import 'providers/room_provider.dart';
import 'providers/profile_provider.dart';

// Điền Project URL và Publishable key từ Supabase Dashboard.
const _supabaseUrl = 'https://mtszmaxtsskhgtvuehcx.supabase.co';
const _supabasePublishableKey = 'sb_publishable_sP8PcmPQ80KFMGLQzh88Gw_dw2KevT2';

Future<void> main() async {
  // Đảm bảo Flutter binding sẵn sàng trước khi chạy app
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL-Outfit.txt');
    yield LicenseEntryWithLineBreaks(['Outfit'], license);
  });

  runApp(
    EduQuestStartup(
      ready: ApiClient.instance.initialize(
        url: const String.fromEnvironment(
          'SUPABASE_URL',
          defaultValue: _supabaseUrl,
        ),
        publishableKey: const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
          defaultValue: _supabasePublishableKey,
        ),
      ),
    ),
  );
}

class EduQuestStartup extends StatelessWidget {
  const EduQuestStartup({super.key, required this.ready});

  final Future<void> ready;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done
          ? const _SessionRoot()
          : const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            ),
    );
  }
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
            ChangeNotifierProvider(
              create: (_) => ProfileProvider(initialProfile: ApiClient.instance.sessionProfile),
            ),

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
