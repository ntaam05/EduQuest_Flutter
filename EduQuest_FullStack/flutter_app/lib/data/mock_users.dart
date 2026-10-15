// lib/data/mock_users.dart
// Mock users để hiển thị leaderboard, phòng thi, và profile.

import '../models/user.dart';

/// User hiện tại đang đăng nhập (mock — chưa có auth thật)
final AppUser currentUser = AppUser(
  id: 'user_001',
  name: 'Nguyễn Văn A',
  avatarEmoji: '🧑‍💻',
  role: 'Student',
  totalQuizzes: 24,
  totalQuestions: 320,
  averageScore: 82.0,
  streakDays: 7,
  xp: 2400,
);

/// Danh sách tất cả mock users (dùng cho leaderboard, phòng thi)
final List<AppUser> mockUsers = [
  currentUser, // Index 0 — user hiện tại
  const AppUser(
    id: 'user_002',
    name: 'Trần Thị B',
    avatarEmoji: '👩‍🎓',
    role: 'Student',
    totalQuizzes: 30,
    totalQuestions: 400,
    averageScore: 90.0,
    streakDays: 14,
    xp: 3600,
  ),
  const AppUser(
    id: 'user_003',
    name: 'Lê Văn C',
    avatarEmoji: '🧑‍🎓',
    role: 'Student',
    totalQuizzes: 18,
    totalQuestions: 240,
    averageScore: 75.0,
    streakDays: 3,
    xp: 1800,
  ),
  const AppUser(
    id: 'user_004',
    name: 'Phạm Thị D',
    avatarEmoji: '👩‍💻',
    role: 'Student',
    totalQuizzes: 35,
    totalQuestions: 480,
    averageScore: 88.0,
    streakDays: 21,
    xp: 4200,
  ),
];
