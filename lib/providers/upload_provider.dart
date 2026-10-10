// lib/providers/upload_provider.dart
// Quản lý state liên quan đến Upload file quiz.
// Mô phỏng việc upload và parse file — sau này thay bằng API call thật.

import 'package:flutter/foundation.dart';
import '../models/quiz.dart';
import '../data/mock_questions.dart';

/// Trạng thái của quá trình upload
enum UploadStatus {
  idle, // Chờ người dùng chọn file
  fileSelected, // Đã chọn file, chờ điền thông tin
  uploading, // Đang upload (loading animation)
  success, // Upload thành công
  error, // Lỗi upload
}

class UploadProvider extends ChangeNotifier {
  // ──────────────────────────────────────────
  // STATE
  // ──────────────────────────────────────────

  UploadStatus _status = UploadStatus.idle;
  String? _selectedFileName; // Tên file đã chọn
  String? _selectedFilePath; // Đường dẫn file
  int? _selectedFileSizeKb; // Kích thước file (KB)
  String? _selectedFileExtension; // Đuôi file (pdf, docx, xlsx, txt)
  String? _errorMessage; // Thông báo lỗi (nếu có)

  // Form fields (người dùng nhập)
  String _quizTitle = '';
  String _quizSubject = '';
  String _quizDescription = '';

  // Getters
  UploadStatus get status => _status;
  String? get selectedFileName => _selectedFileName;
  String? get selectedFilePath => _selectedFilePath;
  int? get selectedFileSizeKb => _selectedFileSizeKb;
  String? get selectedFileExtension => _selectedFileExtension;
  String? get errorMessage => _errorMessage;
  String get quizTitle => _quizTitle;
  String get quizSubject => _quizSubject;
  String get quizDescription => _quizDescription;

  /// File đã được chọn chưa
  bool get hasFile => _selectedFileName != null;

  /// Kích thước file hiển thị thân thiện
  String get fileSizeDisplay {
    if (_selectedFileSizeKb == null) return '';
    if (_selectedFileSizeKb! < 1024) return '${_selectedFileSizeKb} KB';
    return '${(_selectedFileSizeKb! / 1024).toStringAsFixed(1)} MB';
  }

  // ──────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────

  /// Khi người dùng chọn file từ file_picker
  void onFileSelected({
    required String name,
    required String path,
    required int sizeBytes,
  }) {
    _selectedFileName = name;
    _selectedFilePath = path;
    _selectedFileSizeKb = sizeBytes ~/ 1024; // bytes → KB
    _selectedFileExtension = name.split('.').last.toLowerCase();

    // Auto-fill tên bài từ tên file (bỏ đuôi file)
    _quizTitle = name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');

    _status = UploadStatus.fileSelected;
    notifyListeners();
  }

  /// Xóa file đã chọn
  void removeFile() {
    _selectedFileName = null;
    _selectedFilePath = null;
    _selectedFileSizeKb = null;
    _selectedFileExtension = null;
    _status = UploadStatus.idle;
    notifyListeners();
  }

  /// Cập nhật form fields
  void updateTitle(String value) {
    _quizTitle = value;
    notifyListeners();
  }

  void updateSubject(String value) {
    _quizSubject = value;
    notifyListeners();
  }

  void updateDescription(String value) {
    _quizDescription = value;
    notifyListeners();
  }

  /// Mô phỏng upload file (fake async)
  /// Trả về Quiz nếu thành công, null nếu lỗi.
  Future<Quiz?> uploadQuiz() async {
    if (!hasFile) return null;

    _status = UploadStatus.uploading;
    _errorMessage = null;
    notifyListeners();

    // Giả lập delay upload (1.5 giây)
    await Future.delayed(const Duration(milliseconds: 1500));

    // Tạo quiz từ mock data (giả lập parse file)
    final quiz = _mapFileToMockQuiz();

    _status = UploadStatus.success;
    notifyListeners();

    return quiz;
  }

  /// Map file được chọn → Mock Quiz (thay thế bằng parse thật sau)
  Quiz _mapFileToMockQuiz() {
    // Tùy theo extension, trả về bộ câu hỏi phù hợp
    // Trong thực tế: Backend sẽ parse file và trả về câu hỏi
    final questions = flutterQuestions; // Mặc định dùng bộ Flutter

    return Quiz(
      id: 'quiz_upload_${DateTime.now().millisecondsSinceEpoch}',
      title: _quizTitle.isNotEmpty ? _quizTitle : 'Bài ôn tập mới',
      subject: _quizSubject.isNotEmpty ? _quizSubject : 'Chưa phân loại',
      description: _quizDescription.isNotEmpty ? _quizDescription : null,
      questions: questions,
      durationMinutes: 15,
      createdAt: DateTime.now(),
      status: QuizStatus.notStarted,
      iconEmoji: '📄',
    );
  }

  /// Reset toàn bộ state upload
  void reset() {
    _status = UploadStatus.idle;
    _selectedFileName = null;
    _selectedFilePath = null;
    _selectedFileSizeKb = null;
    _selectedFileExtension = null;
    _errorMessage = null;
    _quizTitle = '';
    _quizSubject = '';
    _quizDescription = '';
    notifyListeners();
  }
}
