// lib/models/user.dart
// Model đại diện cho người dùng trong app.
// Dùng cho Mock Data và hiển thị Profile.

class AppUser {
  final String id;
  final String name; // Tên hiển thị
  final String? avatarUrl; // URL ảnh đại diện
  final String? avatarEmoji; // Emoji dùng thay ảnh nếu không có URL
  final String role; // Ví dụ: "Student", "Teacher"
  final int totalQuizzes; // Tổng số bài đã làm
  final int totalQuestions; // Tổng số câu đã trả lời
  final double averageScore; // Điểm trung bình (0-100)
  final int streakDays; // Số ngày streak liên tiếp
  final int xp; // Điểm kinh nghiệm (gamification)

  const AppUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.avatarEmoji,
    this.role = 'Student',
    this.totalQuizzes = 0,
    this.totalQuestions = 0,
    this.averageScore = 0.0,
    this.streakDays = 0,
    this.xp = 0,
  });

  // --- CopyWith ---
  AppUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? avatarEmoji,
    String? role,
    int? totalQuizzes,
    int? totalQuestions,
    double? averageScore,
    int? streakDays,
    int? xp,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      role: role ?? this.role,
      totalQuizzes: totalQuizzes ?? this.totalQuizzes,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      averageScore: averageScore ?? this.averageScore,
      streakDays: streakDays ?? this.streakDays,
      xp: xp ?? this.xp,
    );
  }

  // --- JSON ---
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      avatarEmoji: json['avatar_emoji'] as String?,
      role: json['role'] as String? ?? 'Student',
      totalQuizzes: json['total_quizzes'] as int? ?? 0,
      totalQuestions: json['total_questions'] as int? ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0.0,
      streakDays: json['streak_days'] as int? ?? 0,
      xp: json['xp'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar_url': avatarUrl,
      'avatar_emoji': avatarEmoji,
      'role': role,
      'total_quizzes': totalQuizzes,
      'total_questions': totalQuestions,
      'average_score': averageScore,
      'streak_days': streakDays,
      'xp': xp,
    };
  }
}
