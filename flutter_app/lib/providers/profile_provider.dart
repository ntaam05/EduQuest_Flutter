import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/api_client.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({Map<String, dynamic>? initialProfile}) {
    if (initialProfile != null) {
      _applyProfile(initialProfile);
      unawaited(refreshProfile());
    }
  }

  final ApiClient _api = ApiClient.instance;
  final int _sessionId = ApiClient.instance.sessionId.value;
  AppUser? _user;
  bool _isDarkMode = false;
  String _language = 'vi';
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  bool _disposed = false;
  int _profileRevision = 0;
  Future<void> _pendingUpdate = Future.value();
  String? _errorMessage;
  double _totalStudyHours = 0;
  int _weeklyCompleted = 0;
  List<double> _weeklyScores = List<double>.filled(7, 0);
  final List<String> weekDayLabels = const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  AppUser get user => _user!;
  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<double> get weeklyScores => List.unmodifiable(_weeklyScores);
  double get totalStudyHours => _totalStudyHours;
  int get weeklyCompleted => _weeklyCompleted;
  bool get _active => !_disposed && _sessionId == _api.sessionId.value;

  Future<void> refreshProfile() async {
    if (!_active || _user == null || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final revision = _profileRevision;
      await _pendingUpdate;
      if (!_active) return;
      final profile = await _api.data('profile_get');
      if (!_active) return;
      if (revision == _profileRevision) {
        _applyProfile(profile);
        unawaited(_api.cacheProfile(profile));
        notifyListeners();
      }

      final stats = await _api.data('profile_stats');
      if (!_active) return;
      _weeklyCompleted = (stats['weekly_completed'] as num?)?.toInt() ?? 0;
      _totalStudyHours = (stats['total_study_hours'] as num?)?.toDouble() ?? 0;
      final nextScores = List<double>.filled(7, 0);
      for (final row in (stats['weekly_scores'] as List? ?? const []).whereType<Map>()) {
        final date = DateTime.tryParse(row['date']?.toString() ?? '')?.toLocal();
        final score = (row['score'] as num?)?.toDouble();
        if (date != null && score != null) nextScores[date.weekday - 1] = score;
      }
      _weeklyScores = nextScores;
      if (revision == _profileRevision) _errorMessage = null;
    } catch (error) {
      if (_active) _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      if (_active) notifyListeners();
    }
  }

  void _applyProfile(Map<String, dynamic> json) {
    _user = AppUser.fromJson(json);
    _isDarkMode = json['dark_mode'] as bool? ?? false;
    _language = json['language'] as String? ?? 'vi';
    _notificationsEnabled = json['notifications_enabled'] as bool? ?? true;
  }

  void toggleDarkMode() => setDarkMode(!_isDarkMode);
  void setDarkMode(bool value) => unawaited(_save({'dark_mode': value}));
  void toggleNotifications() => unawaited(_save({'notifications_enabled': !_notificationsEnabled}));

  void setLanguage(String lang) {
    if (lang == 'vi' || lang == 'en') unawaited(_save({'language': lang}));
  }

  Future<bool> updateProfile({required String name, required String avatarEmoji}) =>
      _save({'name': name, 'avatar_emoji': avatarEmoji});

  Future<bool> _save(Map<String, dynamic> changes) async {
    _profileRevision++;
    final request = _pendingUpdate.then((_) async {
      if (!_active) return false;
      try {
        final profile = await _api.data('profile_update', changes);
        if (!_active) return false;
        _applyProfile(profile);
        await _api.cacheProfile(profile);
        _errorMessage = null;
        return _active;
      } catch (error) {
        if (_active) _errorMessage = error.toString();
        return false;
      } finally {
        if (_active) notifyListeners();
      }
    });
    _pendingUpdate = request.then((_) {});
    return request;
  }

  void incrementStats({required int questionsAnswered, required double score}) {
    unawaited(refreshProfile());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
