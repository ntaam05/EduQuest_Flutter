// lib/providers/room_provider.dart
// Quản lý state liên quan đến phòng thi:
// - Tạo phòng
// - Tham gia phòng
// - Trạng thái phòng
// - Leaderboard

import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../models/quiz.dart';
import '../data/mock_quizzes.dart';
import '../data/mock_rooms.dart';
import '../data/mock_users.dart';

/// Trạng thái của quá trình tạo/join phòng
enum RoomActionStatus {
  idle,
  loading,
  success,
  error,
}

class RoomProvider extends ChangeNotifier {
  // ──────────────────────────────────────────
  // STATE
  // ──────────────────────────────────────────

  /// Phòng hiện tại mà user đang ở
  Room? _currentRoom;

  /// Danh sách phòng (để hiển thị ở Room screen)
  List<Room> _rooms = List.from(mockRooms);

  RoomActionStatus _status = RoomActionStatus.idle;
  String? _errorMessage;

  // Getters
  Room? get currentRoom => _currentRoom;
  List<Room> get rooms => _rooms;
  RoomActionStatus get status => _status;
  String? get errorMessage => _errorMessage;

  // ──────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────

  /// Tạo phòng mới (mock)
  Future<Room?> createRoom({
    required Quiz quiz,
    required int maxPlayers,
    required int durationMinutes,
  }) async {
    _status = RoomActionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // Giả lập delay tạo phòng
    await Future.delayed(const Duration(milliseconds: 800));

    // Tạo mã phòng ngẫu nhiên 6 ký tự
    final code = _generateRoomCode();

    final newRoom = Room(
      id: 'room_${DateTime.now().millisecondsSinceEpoch}',
      code: code,
      host: currentUser, // User hiện tại là chủ phòng
      quiz: quiz,
      players: [currentUser], // Chủ phòng tự động vào
      maxPlayers: maxPlayers,
      durationMinutes: durationMinutes,
      status: RoomStatus.waiting,
    );

    _rooms.insert(0, newRoom);
    _currentRoom = newRoom;
    _status = RoomActionStatus.success;
    notifyListeners();

    return newRoom;
  }

  /// Tham gia phòng bằng mã phòng
  Future<Room?> joinRoom(String code) async {
    _status = RoomActionStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // Giả lập delay tìm phòng
    await Future.delayed(const Duration(milliseconds: 600));

    // Tìm phòng với mã tương ứng trong mock data
    final upperCode = code.toUpperCase().trim();
    final room = _rooms.firstWhere(
      (r) => r.code == upperCode,
      orElse: () => Room(
        id: '',
        code: '',
        host: currentUser,
        quiz: mockQuizzes[0],
        players: const [],
        durationMinutes: 15,
      ),
    );

    // Kiểm tra phòng có tồn tại không
    if (room.id.isEmpty) {
      _status = RoomActionStatus.error;
      _errorMessage = 'Không tìm thấy phòng với mã "$code". Vui lòng kiểm tra lại.';
      notifyListeners();
      return null;
    }

    // Kiểm tra phòng có thể vào không
    if (!room.canJoin) {
      _status = RoomActionStatus.error;
      _errorMessage = room.status == RoomStatus.playing
          ? 'Phòng đang trong quá trình thi, không thể vào lúc này.'
          : 'Phòng đã đầy người chơi.';
      notifyListeners();
      return null;
    }

    // Thêm user hiện tại vào phòng
    final updatedRoom = room.copyWith(
      players: [...room.players, currentUser],
    );
    _currentRoom = updatedRoom;
    _status = RoomActionStatus.success;
    notifyListeners();

    return updatedRoom;
  }

  /// Rời phòng
  void leaveRoom() {
    _currentRoom = null;
    _status = RoomActionStatus.idle;
    notifyListeners();
  }

  /// Bắt đầu thi (mock — chủ phòng kích hoạt)
  void startGame() {
    if (_currentRoom == null) return;
    _currentRoom = _currentRoom!.copyWith(status: RoomStatus.playing);
    notifyListeners();
  }

  /// Reset trạng thái lỗi
  void clearError() {
    _status = RoomActionStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Tạo mã phòng ngẫu nhiên 6 ký tự (4 chữ + 2 số)
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const nums = '0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;

    // Lấy 4 chữ cái và 2 số từ timestamp
    final code = StringBuffer();
    for (int i = 0; i < 4; i++) {
      code.write(chars[(random + i * 7) % chars.length]);
    }
    for (int i = 0; i < 2; i++) {
      code.write(nums[(random + i * 13) % nums.length]);
    }
    return code.toString();
  }
}
