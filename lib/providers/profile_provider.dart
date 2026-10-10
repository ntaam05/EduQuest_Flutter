// lib/providers/profile_provider.dart
// Quản lý thông tin profile người dùng hiện tại.
// Bao gồm: thống kê, theme preference, cài đặt.

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../data/mock_users.dart';

class ProfileProvider extends ChangeNotifier {
  // ──────────────────────────────────────────
  // STATE
  // ──────────────────────────────────────────

  /// Người dùng hiện tại đang đăng nhập
  AppUser _user = currentUser;

  /// Dark mode đang bật hay không
  bool _isDarkMode = false;

  /// Ngôn ngữ hiện tại
  String _language = 'vi'; // 'vi' hoặc 'en'

  /// Thông báo có được bật không
  bool _notificationsEnabled = true;

  // Getters
  AppUser get user => _user;
  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get notificationsEnabled => _notificationsEnabled;

  // ──────────────────────────────────────────
  // Mock weekly stats — dùng cho biểu đồ fl_chart
  // ──────────────────────────────────────────

  /// Điểm theo ngày trong tuần (0=Thứ 2 → 6=Chủ nhật)
  final List<double> weeklyScores = [70, 80, 75, 90, 85, 88, 92];

  /// Nhãn ngày trong tuần
  final List<String> weekDayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// Tổng thời gian học (giờ)
  double get totalStudyHours => 48.5;

  /// Số bài hoàn thành tuần này
  int get weeklyCompleted => 5;

  // ──────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────

  /// Bật/tắt dark mode
  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  /// Đặt dark mode trực tiếp
  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  /// Bật/tắt thông báo
  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();
  }

  /// Đổi ngôn ngữ
  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }

  /// Cập nhật thông tin profile (mock)
  void updateProfile({String? name, String? avatarEmoji}) {
    _user = _user.copyWith(
      name: name ?? _user.name,
      avatarEmoji: avatarEmoji ?? _user.avatarEmoji,
    );
    notifyListeners();
  }

  /// Tăng thống kê sau khi làm bài (được gọi từ QuizProvider)
  void incrementStats({required int questionsAnswered, required double score}) {
    _user = _user.copyWith(
      totalQuizzes: _user.totalQuizzes + 1,
      totalQuestions: _user.totalQuestions + questionsAnswered,
      averageScore: (_user.averageScore + score) / 2, // Tính trung bình đơn giản
    );
    notifyListeners();
  }
}
