// lib/models/quiz.dart
// Model đại diện cho một bài trắc nghiệm (bộ câu hỏi).
// Chứa metadata + danh sách câu hỏi + kết quả gần nhất.

import 'question.dart';

/// Trạng thái của bài quiz (dùng để filter trong Review screen)
enum QuizStatus {
  notStarted, // Chưa làm
  inProgress, // Đang làm (đã vào nhưng chưa nộp)
  completed, // Đã hoàn thành
}

class Quiz {
  final String id;
  final String title; // Tên bài
  final String subject; // Môn học (Lập trình, Cơ sở dữ liệu...)
  final String? description; // Mô tả ngắn
  final List<Question> questions; // Danh sách câu hỏi
  final int durationMinutes; // Thời gian làm bài (phút)
  final DateTime createdAt; // Ngày tạo
  final QuizStatus status; // Trạng thái hiện tại
  final double? lastScore; // Điểm lần làm gần nhất (null nếu chưa làm)
  final double progress; // Tiến độ 0.0 → 1.0
  final String? thumbnailUrl; // Ảnh đại diện (optional)
  final String? iconEmoji; // Emoji icon thay thumbnail nếu không có ảnh
  final bool isOwner; // Người đang đăng nhập là chủ bài (được phép xóa)

  const Quiz({
    required this.id,
    required this.title,
    required this.subject,
    this.description,
    required this.questions,
    required this.durationMinutes,
    required this.createdAt,
    this.status = QuizStatus.notStarted,
    this.lastScore,
    this.progress = 0.0,
    this.thumbnailUrl,
    this.iconEmoji,
    this.isOwner = false,
  });

  /// Số câu hỏi trong bài
  int get questionCount => questions.length;

  /// Tên hiển thị trạng thái (dùng trong UI)
  String get statusLabel {
    switch (status) {
      case QuizStatus.notStarted:
        return 'Chưa làm';
      case QuizStatus.inProgress:
        return 'Đang làm';
      case QuizStatus.completed:
        return 'Đã hoàn thành';
    }
  }

  // --- CopyWith để cập nhật quiz (immutable update) ---
  Quiz copyWith({
    String? id,
    String? title,
    String? subject,
    String? description,
    List<Question>? questions,
    int? durationMinutes,
    DateTime? createdAt,
    QuizStatus? status,
    double? lastScore,
    double? progress,
    String? thumbnailUrl,
    String? iconEmoji,
    bool? isOwner,
  }) {
    return Quiz(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      lastScore: lastScore ?? this.lastScore,
      progress: progress ?? this.progress,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      isOwner: isOwner ?? this.isOwner,
    );
  }

  // --- Factory từ JSON ---
  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String?,
      questions: (json['questions'] as List)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList(),
      durationMinutes: json['duration_minutes'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: _statusFromJson(json['status'] as String?),
      lastScore: (json['last_score'] as num?)?.toDouble(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      thumbnailUrl: json['thumbnail_url'] as String?,
      iconEmoji: json['icon_emoji'] as String?,
      isOwner: json['is_owner'] == true,
    );
  }

  static QuizStatus _statusFromJson(String? value) {
    switch (value?.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
      case 'đang làm':
        return QuizStatus.inProgress;
      case 'completed':
      case 'đã hoàn thành':
        return QuizStatus.completed;
      default:
        return QuizStatus.notStarted;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'questions': questions.map((q) => q.toJson()).toList(),
      'duration_minutes': durationMinutes,
      'created_at': createdAt.toIso8601String(),
      'last_score': lastScore,
      'progress': progress,
      'thumbnail_url': thumbnailUrl,
      'icon_emoji': iconEmoji,
    };
  }
}
