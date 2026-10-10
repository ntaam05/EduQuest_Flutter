// lib/models/room.dart
// Model đại diện cho phòng thi trực tuyến (mock).
// Phòng chứa quiz, danh sách người chơi, mã phòng, trạng thái.

import 'user.dart';
import 'quiz.dart';

/// Trạng thái phòng thi
enum RoomStatus {
  waiting, // Đang chờ người chơi
  playing, // Đang thi
  finished, // Đã kết thúc
}

/// Kết quả của một người chơi trong phòng thi
class PlayerResult {
  final AppUser user;
  final int score; // Tổng điểm
  final int correctAnswers; // Số câu đúng
  final int rank; // Xếp hạng

  const PlayerResult({
    required this.user,
    required this.score,
    required this.correctAnswers,
    required this.rank,
  });
}

class Room {
  final String id;
  final String code; // Mã phòng 6 ký tự (VD: ABCD12)
  final AppUser host; // Chủ phòng
  final Quiz quiz; // Bài thi được dùng
  final List<AppUser> players; // Danh sách người chơi
  final int maxPlayers; // Số người tối đa
  final int durationMinutes; // Thời gian thi
  final RoomStatus status; // Trạng thái phòng
  final List<PlayerResult> results; // Kết quả sau khi thi (empty nếu chưa thi)

  const Room({
    required this.id,
    required this.code,
    required this.host,
    required this.quiz,
    required this.players,
    this.maxPlayers = 10,
    required this.durationMinutes,
    this.status = RoomStatus.waiting,
    this.results = const [],
  });

  /// Số người hiện tại trong phòng
  int get currentPlayers => players.length;

  /// Có thể vào phòng không (chưa đầy và đang chờ)
  bool get canJoin => status == RoomStatus.waiting && currentPlayers < maxPlayers;

  /// Tên hiển thị trạng thái
  String get statusLabel {
    switch (status) {
      case RoomStatus.waiting:
        return 'Đang chờ';
      case RoomStatus.playing:
        return 'Đang thi';
      case RoomStatus.finished:
        return 'Đã kết thúc';
    }
  }

  // --- CopyWith ---
  Room copyWith({
    String? id,
    String? code,
    AppUser? host,
    Quiz? quiz,
    List<AppUser>? players,
    int? maxPlayers,
    int? durationMinutes,
    RoomStatus? status,
    List<PlayerResult>? results,
  }) {
    return Room(
      id: id ?? this.id,
      code: code ?? this.code,
      host: host ?? this.host,
      quiz: quiz ?? this.quiz,
      players: players ?? this.players,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      results: results ?? this.results,
    );
  }
}
