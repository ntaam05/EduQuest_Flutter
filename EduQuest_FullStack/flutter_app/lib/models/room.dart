// lib/models/room.dart
// Model đại diện cho phòng thi trực tuyến (mock).
// Phòng chứa quiz, danh sách người chơi, mã phòng, trạng thái.

import 'user.dart';
import 'quiz.dart';

/// Trạng thái phòng thi
enum RoomStatus {
  waiting, // Đang chờ người chơi
  playing, // Đang thi câu hỏi
  showingResults, // Công bố điểm của câu vừa kết thúc
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
  final int durationMinutes; // Thời gian tổng tham khảo
  final int questionDurationSeconds; // Thời gian cho mỗi câu
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
    this.questionDurationSeconds = 25,
    this.status = RoomStatus.waiting,
    this.results = const [],
  });

  factory Room.fromJson(Map<String, dynamic> json, {required Quiz quiz}) {
    final hostJson = (json['host'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final playerJson = (json['players'] as List? ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    final host = AppUser.fromJson({
      'id': hostJson['id'] ?? '0',
      'name': hostJson['name'] ?? 'Người tạo phòng',
      'avatar_emoji': hostJson['avatar_emoji'] ?? '👤',
      'role': 'Student',
    });
    final players = playerJson.map((p) => AppUser.fromJson({
      'id': p['id'] ?? '0',
      'name': p['name'] ?? 'Người chơi',
      'avatar_emoji': p['avatar_emoji'] ?? '👤',
      'role': 'Student',
    })).toList();
    final results = playerJson.where((p) => p['score'] != null).map((p) {
      final player = AppUser.fromJson({
        'id': p['id'] ?? '0',
        'name': p['name'] ?? 'Người chơi',
        'avatar_emoji': p['avatar_emoji'] ?? '👤',
      });
      return PlayerResult(
        user: player,
        score: (p['score'] as num?)?.toInt() ?? 0,
        correctAnswers: (p['correct_answers'] as num?)?.toInt() ?? 0,
        rank: (p['rank'] as num?)?.toInt() ?? 0,
      );
    }).toList();
    final statusValue = (json['status'] as String? ?? 'waiting').toLowerCase();
    return Room(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      host: host,
      quiz: quiz,
      players: players,
      maxPlayers: (json['max_players'] as num?)?.toInt() ?? 10,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? quiz.durationMinutes,
      questionDurationSeconds: (json['question_duration_seconds'] as num?)?.toInt() ?? 25,
      status: statusValue == 'playing' ? RoomStatus.playing : statusValue == 'showingresults' || statusValue == 'showing_results' ? RoomStatus.showingResults : statusValue == 'finished' ? RoomStatus.finished : RoomStatus.waiting,
      results: results,
    );
  }

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
      case RoomStatus.showingResults:
        return 'Công bố điểm';
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
    int? questionDurationSeconds,
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
      questionDurationSeconds: questionDurationSeconds ?? this.questionDurationSeconds,
      status: status ?? this.status,
      results: results ?? this.results,
    );
  }
}
