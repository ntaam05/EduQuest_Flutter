// Quản lý trạng thái bài thi và đồng bộ dữ liệu thông qua REST API.
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../services/api_client.dart';
import '../services/local_database.dart';

class QuizProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  // Backend is the source of truth; never show placeholder quizzes as if they were persisted.
  List<Quiz> _quizzes = [];
  List<Quiz> get quizzes => List.unmodifiable(_quizzes);

  Quiz? _currentQuiz;
  int _currentQuestionIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  DateTime? _startTime;
  int? _attemptId;
  Future<void>? _attemptStartFuture;
  bool _isLoading = false;
  String? _errorMessage;

  Quiz? get currentQuiz => _currentQuiz;
  int get currentQuestionIndex => _currentQuestionIndex;
  Map<int, int> get selectedAnswers => Map.unmodifiable(_selectedAnswers);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Question? get currentQuestion {
    if (_currentQuiz == null || _currentQuestionIndex >= _currentQuiz!.questions.length) return null;
    return _currentQuiz!.questions[_currentQuestionIndex];
  }

  int? get currentSelectedAnswer => currentQuestion == null ? null : _selectedAnswers[currentQuestion!.id];
  bool get hasSelectedCurrentAnswer => currentSelectedAnswer != null;
  bool get isLastQuestion => _currentQuiz != null && _currentQuestionIndex == _currentQuiz!.questions.length - 1;
  double get quizProgress => _currentQuiz == null || _currentQuiz!.questions.isEmpty ? 0 : _selectedAnswers.length / _currentQuiz!.questions.length;

  QuizResult? _lastResult;
  QuizResult? get lastResult => _lastResult;

  // Không tự gọi danh sách quiz ở constructor; nhưng vẫn có thể nạp cache SQLite
  // để ứng dụng có dữ liệu offline theo chuẩn bài học SQLite/SQFlite.
  QuizProvider() {
    unawaited(_hydrateLocalQuizzes());
  }

  Future<void> _hydrateLocalQuizzes() async {
    try {
      final cachedRows = await LocalDatabase.instance.loadQuizCache();
      if (cachedRows.isEmpty) return;
      _quizzes = cachedRows.map((row) => Quiz.fromJson(row)).toList();
      notifyListeners();
    } catch (_) {
      // Bỏ qua khi cache chưa sẵn sàng.
    }
  }

  Future<void> loadQuizzes() async {
    if (!_api.isAuthenticated) {
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final rows = await _api.getList('/api/quizzes');
      final mapped = rows.map((row) => Quiz.fromJson((row as Map).cast<String, dynamic>())).toList();
      _quizzes = mapped;
      await LocalDatabase.instance.saveQuizCache(
        mapped.map((quiz) => quiz.toJson()).toList(),
      );
    } catch (error) {
      final cached = await LocalDatabase.instance.loadQuizCache();
      if (cached.isNotEmpty) {
        _quizzes = cached.map((row) => Quiz.fromJson(row)).toList();
        _errorMessage = null;
      } else {
        _errorMessage = error.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Bắt đầu lượt làm bài ở API. Trạng thái UI được khởi tạo đồng bộ để màn hình phản hồi ngay.
  Future<void> startQuiz(Quiz quiz) {
    _currentQuiz = quiz;
    _currentQuestionIndex = 0;
    _selectedAnswers.clear();
    _startTime = null;
    _lastResult = null;
    _attemptId = null;
    _attemptStartFuture = _createAttempt(quiz.id);
    notifyListeners();
    return _attemptStartFuture!;
  }

  Future<void> _createAttempt(String quizId) async {
    try {
      final response = await _api.post('/api/quizzes/$quizId/attempts');
      _attemptId = (response['id'] as num).toInt();
      _startTime = DateTime.now();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  void selectAnswer(int questionId, int optionIndex) {
    _selectedAnswers[questionId] = optionIndex;
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentQuiz != null && _currentQuestionIndex < _currentQuiz!.questions.length - 1) {
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  void goToQuestion(int index) {
    if (_currentQuiz != null && index >= 0 && index < _currentQuiz!.questions.length) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  /// Server quyết định điểm số; ứng dụng không tin điểm do client tự tính.
  Future<QuizResult> submitQuiz() async {
    if (_currentQuiz == null) throw StateError('Không có quiz đang làm.');
    if (_lastResult != null) return _lastResult!;
    if (_attemptStartFuture != null) await _attemptStartFuture;
    if (_attemptId == null) throw StateError(_errorMessage ?? 'Không tạo được lượt làm bài trên server.');

    final elapsed = _startTime == null ? Duration.zero : DateTime.now().difference(_startTime!);
    final answers = <String, int>{};
    _selectedAnswers.forEach((key, value) => answers[key.toString()] = value);
    final response = await _api.post('/api/quizzes/attempts/$_attemptId/submit', {
      'answers': answers,
      'time_spent_seconds': elapsed.inSeconds,
    });

    final correct = (response['correct_answers'] as num?)?.toInt() ?? 0;
    final total = (response['total_questions'] as num?)?.toInt() ?? _currentQuiz!.questions.length;
    final reviewRows = (response['review_questions'] as List? ?? const [])
        .whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
    final keyByQuestion = <int, Map<String, dynamic>>{};
    for (final row in reviewRows) {
      final id = (row['id'] as num?)?.toInt();
      if (id != null) keyByQuestion[id] = row;
    }

    final reviewedQuestions = _currentQuiz!.questions.map((question) {
      final key = keyByQuestion[question.id];
      if (key == null) return question;
      return question.copyWith(
        correctAnswer: (key['correct_answer'] as num?)?.toInt() ?? -1,
        explanation: key['explanation'] as String?,
      );
    }).toList();
    final reviewedQuiz = _currentQuiz!.copyWith(
      questions: reviewedQuestions,
      status: QuizStatus.completed,
      lastScore: (response['score_out_of_10'] as num?)?.toDouble() ?? (total == 0 ? 0 : 10 * correct / total),
      progress: 1,
    );

    final result = QuizResult(
      quiz: reviewedQuiz,
      correctAnswers: correct,
      totalQuestions: total,
      timeSpent: Duration(seconds: (response['time_spent_seconds'] as num?)?.toInt() ?? elapsed.inSeconds),
      selectedAnswers: Map<int, int>.from(_selectedAnswers),
    );
    _lastResult = result;
    _currentQuiz = reviewedQuiz;
    final index = _quizzes.indexWhere((q) => q.id == reviewedQuiz.id);
    if (index >= 0) _quizzes[index] = reviewedQuiz;
    notifyListeners();
    unawaited(loadQuizzes());
    return result;
  }

  // ───────── Lịch sử làm bài: GET /api/quizzes/attempts/mine ─────────
  List<Map<String, dynamic>> _attempts = const [];
  bool _loadingAttempts = false;
  String? _attemptsError;
  List<Map<String, dynamic>> get attempts => _attempts;
  bool get loadingAttempts => _loadingAttempts;
  String? get attemptsError => _attemptsError;

  Future<void> loadAttempts() async {
    _loadingAttempts = true;
    _attemptsError = null;
    notifyListeners();
    try {
      final rows = await _api.getList('/api/quizzes/attempts/mine');
      _attempts = rows.whereType<Map>().map((row) => row.cast<String, dynamic>()).toList();
    } catch (error) {
      _attemptsError = error.toString();
    } finally {
      _loadingAttempts = false;
      notifyListeners();
    }
  }

  // ───────── Tạo bài thủ công: POST /api/quizzes ─────────
  /// [questions]: mỗi phần tử có dạng
  /// {'text': ..., 'options': [{'text': ...}, ...], 'correct_answer_index': n, 'explanation': ...}
  Future<Quiz> createQuiz({
    required String title,
    required String subject,
    String? description,
    required int durationMinutes,
    String? iconEmoji,
    required List<Map<String, dynamic>> questions,
  }) async {
    final json = await _api.post('/api/quizzes', {
      'title': title,
      'subject': subject,
      'description': (description == null || description.trim().isEmpty) ? null : description.trim(),
      'duration_minutes': durationMinutes,
      'icon_emoji': iconEmoji,
      'questions': questions,
    });
    final quiz = Quiz.fromJson(json);
    await loadQuizzes();
    return quiz;
  }

  // ───────── Xóa bài: DELETE /api/quizzes/{id} ─────────
  Future<void> deleteQuiz(String quizId) async {
    await _api.delete('/api/quizzes/$quizId');
    _quizzes.removeWhere((quiz) => quiz.id == quizId);
    notifyListeners();
  }

  void addQuiz(Quiz quiz) {
    if (quiz.questions.isEmpty) return; // Bài upload chưa được trích xuất câu hỏi không thể làm bài.
    _quizzes.removeWhere((item) => item.id == quiz.id);
    _quizzes.insert(0, quiz);
    notifyListeners();
  }

  List<Quiz> searchQuizzes(String query) {
    if (query.trim().isEmpty) return _quizzes;
    final needle = query.toLowerCase().trim();
    return _quizzes.where((quiz) => quiz.title.toLowerCase().contains(needle) ||
        quiz.subject.toLowerCase().contains(needle) ||
        (quiz.description?.toLowerCase().contains(needle) ?? false)).toList();
  }

  List<Quiz> filterByStatus(QuizStatus? status) => status == null ? _quizzes : _quizzes.where((q) => q.status == status).toList();
}

class QuizResult {
  final Quiz quiz;
  final int correctAnswers;
  final int totalQuestions;
  final Duration timeSpent;
  final Map<int, int> selectedAnswers;

  const QuizResult({required this.quiz, required this.correctAnswers, required this.totalQuestions, required this.timeSpent, required this.selectedAnswers});

  int get incorrectAnswers => totalQuestions - correctAnswers;
  double get scorePercent => totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;
  double get scoreOutOf10 => totalQuestions > 0 ? (correctAnswers / totalQuestions) * 10 : 0;
  int get xpEarned => scorePercent.round();
  String get timeSpentFormatted {
    final minutes = timeSpent.inMinutes.toString().padLeft(2, '0');
    final seconds = (timeSpent.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  bool isCorrect(int questionId) {
    final question = quiz.questions.firstWhere((q) => q.id == questionId);
    return selectedAnswers[questionId] == question.correctAnswer;
  }
}
