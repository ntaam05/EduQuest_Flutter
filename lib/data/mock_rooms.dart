// lib/data/mock_rooms.dart
// Mock rooms (phòng thi) dùng để demo chức năng Tạo phòng / Tham gia phòng.

import '../models/room.dart';
import 'mock_users.dart';
import 'mock_quizzes.dart';

/// Danh sách mock rooms.
/// ABCD12 là phòng hợp lệ để test tính năng "Tham gia phòng".
final List<Room> mockRooms = [
  Room(
    id: 'room_001',
    code: 'ABCD12', // Mã phòng để test join
    host: mockUsers[0], // Nguyễn Văn A là chủ phòng
    quiz: mockQuizzes[0], // Dùng bài Flutter Cơ Bản
    players: [mockUsers[0], mockUsers[1]], // 2 người đã vào
    maxPlayers: 10,
    durationMinutes: 15,
    status: RoomStatus.waiting, // Đang chờ bắt đầu
    results: const [],
  ),
  Room(
    id: 'room_002',
    code: 'XYZ789',
    host: mockUsers[1], // Trần Thị B là chủ phòng
    quiz: mockQuizzes[1], // Dùng bài CSDL
    players: [mockUsers[1], mockUsers[2], mockUsers[3]],
    maxPlayers: 5,
    durationMinutes: 20,
    status: RoomStatus.playing, // Đang thi
    results: const [],
  ),
];

/// Leaderboard mock sau khi thi xong phòng ABCD12
final List<PlayerResult> mockLeaderboard = [
  PlayerResult(
    user: mockUsers[1], // Trần Thị B — hạng 1
    score: 980,
    correctAnswers: 9,
    rank: 1,
  ),
  PlayerResult(
    user: mockUsers[0], // Nguyễn Văn A — hạng 2
    score: 850,
    correctAnswers: 8,
    rank: 2,
  ),
  PlayerResult(
    user: mockUsers[2], // Lê Văn C — hạng 3
    score: 720,
    correctAnswers: 7,
    rank: 3,
  ),
];
