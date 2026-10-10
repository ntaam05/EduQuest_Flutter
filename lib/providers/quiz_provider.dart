// lib/providers/quiz_provider.dart
// Quản lý state liên quan đến quiz:
// - Danh sách quiz
// - Quiz đang làm
// - Câu hỏi hiện tại + đáp án đã chọn
// - Kết quả bài làm

import 'package:flutter/foundation.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import '../data/mock_quizzes.dart';

class QuizProvider extends ChangeNotifier {
  // ──────────────────────────────────────────
  // STATE: Danh sách quiz
  // ──────────────────────────────────────────

  /// Danh sách tất cả quiz có sẵn
  List<Quiz> _quizzes = List.from(mockQuizzes);

  /// Getter công khai — đọc nhưng không sửa trực tiếp
  List<Quiz> get quizzes => _quizzes;

  // ──────────────────────────────────────────
  // STATE: Quiz đang làm
  // ──────────────────────────────────────────

  Quiz? _currentQuiz; // Quiz đang làm
  int _currentQuestionIndex = 0; // Index câu hỏi hiện tại (0-based)

  /// Map<questionId, selectedOptionIndex> — lưu đáp án đã chọn cho từng câu
  final Map<int, int> _selectedAnswers = {};

  /// Thời gian bắt đầu làm bài
  DateTime? _startTime;

  Quiz? get currentQuiz => _currentQuiz;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<int, int> get selectedAnswers => Map.unmodifiable(_selectedAnswers);

  /// Câu hỏi hiện tại (null nếu chưa bắt đầu)
  Question? get currentQuestion {
    if (_currentQuiz == null) return null;
    if (_currentQuestionIndex >= _currentQuiz!.questions.length) return null;
    return _currentQuiz!.questions[_currentQuestionIndex];
  }

  /// Đáp án đã chọn cho câu hiện tại (null nếu chưa chọn)
  int? get currentSelectedAnswer {
    if (currentQuestion == null) return null;
    return _selectedAnswers[currentQuestion!.id];
  }

  /// Đã chọn câu hiện tại chưa
  bool get hasSelectedCurrentAnswer => currentSelectedAnswer != null;

  /// Đây có phải câu cuối cùng không
  bool get isLastQuestion {
    if (_currentQuiz == null) return false;
    return _currentQuestionIndex == _currentQuiz!.questions.length - 1;
  }

  /// Progress (0.0 → 1.0) dựa trên số câu đã trả lời
  double get quizProgress {
    if (_currentQuiz == null) return 0.0;
    return _selectedAnswers.length / _currentQuiz!.questions.length;
  }

  // ──────────────────────────────────────────
  // STATE: Kết quả
  // ──────────────────────────────────────────

  QuizResult? _lastResult; // Kết quả bài làm gần nhất

  QuizResult? get lastResult => _lastResult;

  // ──────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────

  /// Bắt đầu làm quiz — reset state cũ
  void startQuiz(Quiz quiz) {
    _currentQuiz = quiz;
    _currentQuestionIndex = 0;
    _selectedAnswers.clear();
    _startTime = DateTime.now();
    _lastResult = null;
    notifyListeners(); // Thông báo UI rebuild
  }

  /// Chọn đáp án cho câu hiện tại
  void selectAnswer(int questionId, int optionIndex) {
    _selectedAnswers[questionId] = optionIndex;
    notifyListeners();
  }

  /// Chuyển sang câu tiếp theo
  void nextQuestion() {
    if (_currentQuiz == null) return;
    if (_currentQuestionIndex < _currentQuiz!.questions.length - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  /// Quay lại câu trước
  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  /// Nhảy đến câu hỏi bất kỳ
  void goToQuestion(int index) {
    if (_currentQuiz == null) return;
    if (index >= 0 && index < _currentQuiz!.questions.length) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  /// Nộp bài — tính điểm và lưu kết quả
  QuizResult submitQuiz() {
    if (_currentQuiz == null) {
      throw StateError('Không có quiz đang làm.');
    }

    // Tính thời gian làm bài
    final elapsed = _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    // Tính số câu đúng
    int correctCount = 0;
    for (final question in _currentQuiz!.questions) {
      final selected = _selectedAnswers[question.id];
      if (selected == question.correctAnswer) {
        correctCount++;
      }
    }

    // Tạo kết quả
    final result = QuizResult(
      quiz: _currentQuiz!,
      correctAnswers: correctCount,
      totalQuestions: _currentQuiz!.questions.length,
      timeSpent: elapsed,
      selectedAnswers: Map.from(_selectedAnswers),
    );

    _lastResult = result;

    // Cập nhật trạng thái quiz trong danh sách
    _updateQuizStatus(result);

    notifyListeners();
    return result;
  }

  /// Cập nhật trạng thái và điểm cho quiz sau khi nộp bài
  void _updateQuizStatus(QuizResult result) {
    final index = _quizzes.indexWhere((q) => q.id == result.quiz.id);
    if (index != -1) {
      _quizzes[index] = _quizzes[index].copyWith(
        status: QuizStatus.completed,
        lastScore: result.scoreOutOf10,
        progress: 1.0,
      );
    }
  }

  /// Thêm quiz mới (sau khi upload)
  void addQuiz(Quiz quiz) {
    _quizzes.insert(0, quiz); // Thêm vào đầu danh sách
    notifyListeners();
  }

  /// Tìm kiếm quiz theo từ khóa
  List<Quiz> searchQuizzes(String query) {
    if (query.isEmpty) return _quizzes;
    final q = query.toLowerCase();
    return _quizzes.where((quiz) {
      return quiz.title.toLowerCase().contains(q) ||
          quiz.subject.toLowerCase().contains(q) ||
          (quiz.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Lọc quiz theo trạng thái
  List<Quiz> filterByStatus(QuizStatus? status) {
    if (status == null) return _quizzes;
    return _quizzes.where((q) => q.status == status).toList();
  }
}

// ──────────────────────────────────────────
// MODEL PHỤ: QuizResult (kết quả bài làm)
// Đặt cùng file cho gọn vì chỉ dùng nội bộ
// ──────────────────────────────────────────

class QuizResult {
  final Quiz quiz;
  final int correctAnswers; // Số câu đúng
  final int totalQuestions; // Tổng số câu
  final Duration timeSpent; // Thời gian làm bài
  final Map<int, int> selectedAnswers; // questionId → optionIndex đã chọn

  const QuizResult({
    required this.quiz,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.timeSpent,
    required this.selectedAnswers,
  });

  /// Số câu sai
  int get incorrectAnswers => totalQuestions - correctAnswers;

  /// Phần trăm điểm (0-100)
  double get scorePercent =>
      totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;

  /// Điểm trên thang 10
  double get scoreOutOf10 =>
      totalQuestions > 0 ? (correctAnswers / totalQuestions) * 10 : 0;

  /// XP nhận được (gamification)
  int get xpEarned => (scorePercent).round();

  /// Thời gian format "mm:ss"
  String get timeSpentFormatted {
    final minutes = timeSpent.inMinutes.toString().padLeft(2, '0');
    final seconds = (timeSpent.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Câu hỏi đã trả lời đúng không (dùng trong review)
  bool isCorrect(int questionId) {
    final question = quiz.questions.firstWhere((q) => q.id == questionId);
    return selectedAnswers[questionId] == question.correctAnswer;
  }
}
