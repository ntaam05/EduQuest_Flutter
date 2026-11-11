// Quản lý phòng thi qua REST API; mọi thay đổi đều được lưu trong database.
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/quiz.dart';
import '../models/room.dart';
import '../services/api_client.dart';

/// Trạng thái thao tác phòng.
enum RoomActionStatus { idle, loading, success, error }

class RoomProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  final int _sessionId = ApiClient.instance.sessionId.value;
  bool _disposed = false;
  bool get _active => !_disposed && _sessionId == _api.sessionId.value;

  @override
  void notifyListeners() {
    if (_active) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  Room? _currentRoom;
  List<Room> _rooms = [];
  RoomActionStatus _status = RoomActionStatus.idle;
  String? _errorMessage;
  // Cache only real quizzes that have come from the API or were just uploaded.
  final Map<String, Quiz> _quizCache = {};

  RoomProvider() { if (_api.isAuthenticated) unawaited(loadRooms()); }

  Room? get currentRoom => _currentRoom;
  List<Room> get rooms => List.unmodifiable(_rooms);
  RoomActionStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Future<void> loadRooms() async {
    if (!_active) return;
    try {
      final rows = await _api.roomList();
      final mapped = <Room>[];
      for (final value in rows) {
        if (value is Map) mapped.add(await _roomFromJson(value.cast<String, dynamic>()));
      }
      _rooms = mapped;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<Quiz> _resolveQuiz(Map<String, dynamic> json) async {
    final id = json['quiz_id']?.toString() ?? '';
    // Đã có đủ câu hỏi trong cache thì không gọi lại API mỗi lần làm mới phòng (lobby poll 2 giây/lần).
    final cachedQuiz = _quizCache[id];
    if (cachedQuiz != null && cachedQuiz.questions.isNotEmpty) return cachedQuiz;
    // Ưu tiên dữ liệu thật. Cache mock chỉ là fallback khi API chi tiết không truy cập được.
    try {
      final raw = await _api.data('quiz_get', {'quiz_id': id});
      final quiz = Quiz.fromJson(raw);
      _quizCache[id] = quiz;
      return quiz;
    } catch (_) {
      final cached = _quizCache[id];
      if (cached != null) return cached;
      return Quiz(
        id: id,
        title: json['quiz_title']?.toString() ?? 'Bài thi',
        subject: 'Chưa phân loại',
        questions: const [],
        durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 15,
        createdAt: DateTime.now(),
        iconEmoji: '🏆',
      );
    }
  }

  Future<Room> _roomFromJson(Map<String, dynamic> json) async {
    final quiz = await _resolveQuiz(json);
    return Room.fromJson(json, quiz: quiz);
  }

  Future<Room?> createRoom({required Quiz quiz, required int maxPlayers, required int durationMinutes, int questionDurationSeconds = 25}) async {
    _setLoading();
    try {
      _quizCache[quiz.id] = quiz;
      final json = await _api.room('create', {
        'quiz_id': quiz.id,
        'max_players': maxPlayers,
        'duration_minutes': durationMinutes,
        'question_duration_seconds': questionDurationSeconds,
      });
      final room = Room.fromJson(json, quiz: quiz);
      _currentRoom = room;
      _upsertRoom(room);
      _status = RoomActionStatus.success;
      notifyListeners();
      return room;
    } catch (error) {
      _fail(error);
      return null;
    }
  }

  Future<Room?> joinRoom(String code) async {
    _setLoading();
    try {
      final json = await _api.room('join', {'code': code.toUpperCase().trim()});
      final room = await _roomFromJson(json);
      _currentRoom = room;
      _upsertRoom(room);
      _status = RoomActionStatus.success;
      notifyListeners();
      return room;
    } catch (error) {
      _fail(error);
      return null;
    }
  }

  /// Tải phòng theo mã để hỗ trợ mở lại màn hình/lấy trạng thái sau khi ứng dụng kết nối lại.
  Future<Room?> loadRoomByCode(String code) async {
    try {
      final json = await _api.room('by_code', {'code': code.toUpperCase().trim()});
      final room = await _roomFromJson(json);
      _currentRoom = room;
      _upsertRoom(room);
      _errorMessage = null;
      notifyListeners();
      return room;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  /// làm mới phòng đang mở khi đã biết id (nhẹ hơn tra theo mã).
  Future<Room?> refreshRoomById(String roomId) async {
    try {
      final json = await _api.room('get', {'room_id': roomId});
      final room = await _roomFromJson(json);
      _currentRoom = room;
      _upsertRoom(room);
      _errorMessage = null;
      notifyListeners();
      return room;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  /// Đọc trạng thái có phân quyền qua RPC khi nhận tín hiệu Realtime hoặc lúc kết nối lại.
  Future<Map<String, dynamic>> loadGameState(String roomId) => _api.room('state', {'room_id': roomId});

  Future<Room?> refreshRoom(String code) => loadRoomByCode(code);

  Future<void> leaveRoom() async {
    final room = _currentRoom;
    if (room != null) {
      try { await _api.room('leave', {'room_id': room.id}); } catch (error) { _errorMessage = error.toString(); }
    }
    _currentRoom = null;
    _status = RoomActionStatus.idle;
    await loadRooms();
    notifyListeners();
  }

  Future<bool> startGame() async {
    final room = _currentRoom;
    if (room == null) return false;
    _setLoading();
    try {
      await _api.room('start', {'room_id': room.id});
      _currentRoom = room.copyWith(status: RoomStatus.playing);
      _upsertRoom(_currentRoom!);
      _status = RoomActionStatus.success;
      notifyListeners();
      return true;
    } catch (error) {
      _fail(error);
      return false;
    }
  }

  void clearError() {
    _status = RoomActionStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void _upsertRoom(Room room) {
    _rooms.removeWhere((item) => item.id == room.id);
    _rooms.insert(0, room);
  }

  void _setLoading() {
    _status = RoomActionStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _fail(Object error) {
    _status = RoomActionStatus.error;
    _errorMessage = error.toString();
    notifyListeners();
  }
}
