// lib/models/question.dart
// Model đại diện cho một câu hỏi trắc nghiệm.
// Thiết kế sạch để dễ dàng parse từ JSON sau này khi tích hợp Backend.

class Question {
  final int id;
  final String question; // Nội dung câu hỏi
  final List<String> options; // Danh sách 4 đáp án
  final int correctAnswer; // Index của đáp án đúng (0-based)
  final String? explanation; // Giải thích đáp án (optional)

  const Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
  });

  // --- Factory từ JSON (chuẩn bị sẵn cho Backend) ---
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswer: json['correct_answer'] as int,
      explanation: json['explanation'] as String?,
    );
  }

  // --- Chuyển sang JSON (dùng khi lưu trữ hoặc gửi API) ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correct_answer': correctAnswer,
      'explanation': explanation,
    };
  }
}
