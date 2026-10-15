// lib/data/mock_quizzes.dart
// 3 bộ quiz mock data, mỗi bộ dùng câu hỏi từ mock_questions.dart.
// Đây là dữ liệu ban đầu — Provider sẽ load và quản lý danh sách này.

import '../models/quiz.dart';
import 'mock_questions.dart';

/// Danh sách các quiz có sẵn trong app (mock).
/// Sau này thay bằng API call từ Backend.
final List<Quiz> mockQuizzes = [
  Quiz(
    id: 'quiz_flutter_01',
    title: 'Flutter Cơ Bản',
    subject: 'Lập trình di động',
    description: 'Kiểm tra kiến thức cơ bản về Flutter framework và Dart.',
    questions: flutterQuestions, // 10 câu hỏi Flutter
    durationMinutes: 15,
    createdAt: DateTime(2026, 10, 1),
    status: QuizStatus.completed, // Đã làm
    lastScore: 8.0, // Điểm gần nhất: 8/10
    progress: 1.0, // Đã làm xong
    iconEmoji: '📱',
  ),
  Quiz(
    id: 'quiz_db_01',
    title: 'Cơ Sở Dữ Liệu',
    subject: 'Cơ sở dữ liệu',
    description: 'Ôn tập SQL, quan hệ bảng, và các khái niệm database quan trọng.',
    questions: databaseQuestions, // 10 câu hỏi Database
    durationMinutes: 20,
    createdAt: DateTime(2026, 10, 3),
    status: QuizStatus.inProgress, // Đang làm
    lastScore: null, // Chưa hoàn thành
    progress: 0.6, // Đã làm 60%
    iconEmoji: '🗄️',
  ),
  Quiz(
    id: 'quiz_oop_01',
    title: 'Lập Trình Hướng Đối Tượng',
    subject: 'Lập trình',
    description: 'Các khái niệm OOP: Encapsulation, Inheritance, Polymorphism, Abstraction.',
    questions: oopQuestions, // 10 câu hỏi OOP
    durationMinutes: 15,
    createdAt: DateTime(2026, 10, 5),
    status: QuizStatus.notStarted, // Chưa làm
    lastScore: null,
    progress: 0.0,
    iconEmoji: '🏗️',
  ),
];
