// Hồ sơ người dùng và cài đặt được đồng bộ với EduQuest REST API.
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/mock_users.dart';
import '../models/user.dart';
import '../services/api_client.dart';
import '../services/local_database.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  AppUser _user = currentUser;
  int _profileRequestVersion = 0;
  bool _isDarkMode = false;
  String _language = 'vi';
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  String? _errorMessage;
  double _totalStudyHours = 0;
  int _weeklyCompleted = 0;
  List<double> _weeklyScores = List<double>.filled(7, 0);
  final List<String> weekDayLabels = const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  // Không tự gọi API trong constructor. Để phù hợp với bài học SQLite/SQFlite,
  // app sẽ lấy dữ liệu cache cục bộ nếu có trước khi users tương tác.
  ProfileProvider() {
    unawaited(_hydrateLocalProfile());
  }

  Future<void> _hydrateLocalProfile() async {
    try {
      final cached = await LocalDatabase.instance.loadProfileCache();
      if (cached == null || cached.isEmpty) return;
      _applyProfile(cached);
      notifyListeners();
    } catch (_) {
      // Bỏ qua nếu cache chưa sẵn sàng.
    }
  }

  AppUser get user => _user;
  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<double> get weeklyScores => List.unmodifiable(_weeklyScores);
  double get totalStudyHours => _totalStudyHours;
  int get weeklyCompleted => _weeklyCompleted;

  Future<void> refreshProfile() async {
    if (!_api.isAuthenticated) {
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    final requestVersion = ++_profileRequestVersion;
    _isLoading = true;
    notifyListeners();
    try {
      final profile = await _api.get('/api/profile');
      if (requestVersion != _profileRequestVersion) return;
      _applyProfile(profile);
      await LocalDatabase.instance.saveProfileCache(profile);

      final stats = await _api.get('/api/profile/stats');
      if (requestVersion != _profileRequestVersion) return;
      _weeklyCompleted = (stats['weekly_completed'] as num?)?.toInt() ?? 0;
      _totalStudyHours = (stats['total_study_hours'] as num?)?.toDouble() ?? 0;
      final rows = (stats['weekly_scores'] as List? ?? const []).whereType<Map>().map((r) => r.cast<String, dynamic>()).toList();
      final nextScores = List<double>.filled(7, 0);
      for (final row in rows) {
        final dateRaw = row['date']?.toString();
        final score = (row['score'] as num?)?.toDouble();
        if (dateRaw == null || score == null) continue;
        final date = DateTime.tryParse(dateRaw)?.toLocal();
        if (date != null) {
          // DateTime.weekday: Monday=1 ... Sunday=7.
          nextScores[date.weekday - 1] = score;
        }
      }
      _weeklyScores = nextScores;
      _errorMessage = null;
    } catch (error) {
      if (requestVersion != _profileRequestVersion) return;
      final cached = await LocalDatabase.instance.loadProfileCache();
      if (cached != null && cached.isNotEmpty) {
        _applyProfile(cached);
      }
      _errorMessage = error.toString();
    } finally {
      if (requestVersion == _profileRequestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _applyProfile(Map<String, dynamic> json) {
    _user = AppUser.fromJson(json);
    _isDarkMode = json['dark_mode'] as bool? ?? false;
    _language = json['language'] as String? ?? 'vi';
    _notificationsEnabled = json['notifications_enabled'] as bool? ?? true;
  }

  void toggleDarkMode() => setDarkMode(!_isDarkMode);
  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
    unawaited(_persistSettings());
  }

  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();
    unawaited(_persistSettings());
  }

  void setLanguage(String lang) {
    if (lang != 'vi' && lang != 'en') return;
    _language = lang;
    notifyListeners();
    unawaited(_persistSettings());
  }

  Future<void> updateProfile({String? name, String? avatarEmoji}) async {
    final nextName = (name ?? _user.name).trim();
    final nextAvatar = (avatarEmoji ?? _user.avatarEmoji ?? '👤').trim();

    try {
      final json = await _api.put('/api/profile', {
        'name': nextName.isEmpty ? _user.name : nextName,
        'avatar_emoji': nextAvatar.isEmpty ? (_user.avatarEmoji ?? '👤') : nextAvatar,
      });
      _applyProfile(json);
      await LocalDatabase.instance.saveProfileCache(json);
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> _persistSettings() async {
    try {
      final json = await _api.put('/api/profile', {
        'dark_mode': _isDarkMode,
        'notifications_enabled': _notificationsEnabled,
        'language': _language,
      });
      _applyProfile(json);
      await LocalDatabase.instance.saveProfileCache(json);
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  /// Điểm và thống kê đã được tính trên server sau khi nộp bài, chỉ tải lại để UI cập nhật.
  void incrementStats({required int questionsAnswered, required double score}) {
    unawaited(refreshProfile());
  }
}
