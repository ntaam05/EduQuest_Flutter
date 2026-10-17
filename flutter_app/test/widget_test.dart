// test/widget_test.dart
// Test cơ bản — kiểm tra app khởi động được.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:doanmon_eduquest/app.dart';
import 'package:doanmon_eduquest/providers/quiz_provider.dart';
import 'package:doanmon_eduquest/providers/upload_provider.dart';
import 'package:doanmon_eduquest/providers/room_provider.dart';
import 'package:doanmon_eduquest/providers/profile_provider.dart';

void main() {
  testWidgets('App khởi động thành công', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProfileProvider()),
          ChangeNotifierProvider(create: (_) => QuizProvider()),
          ChangeNotifierProvider(create: (_) => UploadProvider()),
          ChangeNotifierProvider(create: (_) => RoomProvider()),
        ],
        child: const QuizUpApp(),
      ),
    );
    // Chỉ test app không crash khi khởi động
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('Provider mới tạo không tự fetch khi chưa có tương tác user', () {
    final profileProvider = ProfileProvider();
    final quizProvider = QuizProvider();
    final roomProvider = RoomProvider();

    expect(profileProvider.isLoading, isFalse);
    expect(profileProvider.errorMessage, isNull);
    expect(quizProvider.isLoading, isFalse);
    expect(quizProvider.errorMessage, isNull);
    expect(roomProvider.status, RoomActionStatus.idle);
    expect(roomProvider.errorMessage, isNull);
  });
}
