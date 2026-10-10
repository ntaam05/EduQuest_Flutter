// lib/app.dart
// Root widget của ứng dụng.
// Cấu hình MaterialApp.router với theme và router.
// Lắng nghe ProfileProvider để áp dụng dark mode động.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/profile_provider.dart';

class QuizUpApp extends StatelessWidget {
  const QuizUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe ProfileProvider để biết khi dark mode thay đổi
    final profileProvider = context.watch<ProfileProvider>();

    return MaterialApp.router(
      title: 'QuizUp', // Tên hiển thị trên task manager

      // --- Theme ---
      theme: AppTheme.lightTheme, // Light mode
      darkTheme: AppTheme.darkTheme, // Dark mode
      // Chọn theme theo setting của user, không theo hệ thống
      themeMode: profileProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // --- Router ---
      routerConfig: appRouter, // GoRouter đã cấu hình ở app_router.dart

      // --- Misc ---
      debugShowCheckedModeBanner: false, // Ẩn banner "DEBUG" góc phải
    );
  }
}
