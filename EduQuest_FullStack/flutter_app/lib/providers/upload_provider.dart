// Upload file thật lên backend; server lưu file và metadata xuống SQLite.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import '../models/quiz.dart';
import '../services/api_client.dart';

enum UploadStatus { idle, fileSelected, uploading, success, error }

/// Kết quả mở hộp thoại chọn file trên máy tính chạy API.
enum PcPickResult { picked, cancelled, unavailable }

class UploadProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  UploadStatus _status = UploadStatus.idle;
  String? _selectedFileName;
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  int? _selectedFileSizeKb;
  String? _selectedFileExtension;
  String? _errorMessage;
  String _quizTitle = '';
  String _quizSubject = '';
  String _quizDescription = '';
  int _lastUploadQuestionCount = 0;
  String? _lastUploadMessage;
  String? _lastParsingMode;
  List<String> _lastUploadWarnings = const [];
  // ── File trong thư mục inbox trên máy tính chạy API (dùng được từ Android Emulator) ──
  bool _fromInbox = false;
  List<Map<String, dynamic>> _inboxFiles = const [];
  String? _inboxFolder;
  bool _loadingInbox = false;
  String? _inboxError;

  List<Map<String, dynamic>> get inboxFiles => _inboxFiles;
  String? get inboxFolder => _inboxFolder;
  bool get loadingInbox => _loadingInbox;
  String? get inboxError => _inboxError;
  bool get fromInbox => _fromInbox;

  /// GET /api/uploads/inbox
  Future<void> loadInbox() async {
    _loadingInbox = true;
    _inboxError = null;
    notifyListeners();
    try {
      final json = await _api.get('/api/uploads/inbox');
      _inboxFolder = json['folder']?.toString();
      _inboxFiles = (json['files'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .toList();
    } catch (error) {
      _inboxError = error.toString();
    } finally {
      _loadingInbox = false;
      notifyListeners();
    }
  }

  /// Bảo API mở hộp thoại chọn file của Windows NGAY TRÊN MÁY TÍNH (POST /api/uploads/pick-from-pc).
  /// Dùng khi app chạy trên Android Emulator/điện thoại. File chọn xong được chọn sẵn để nhập.
  Future<PcPickResult> pickFromComputer() async {
    try {
      final json = await _api.postWithTimeout(
        '/api/uploads/pick-from-pc',
        timeout: const Duration(minutes: 6),
      );
      if (json['picked'] != true) return PcPickResult.cancelled;
      selectInboxFile(
        name: json['name'].toString(),
        sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      );
      unawaited(loadInbox());
      return PcPickResult.picked;
    } on ApiException catch (error) {
      if (error.statusCode == 501) return PcPickResult.unavailable;
      rethrow;
    }
  }

  /// Chọn một file đang nằm trong thư mục inbox của máy tính.
  void selectInboxFile({required String name, required int sizeBytes}) {
    onFileSelected(name: name, path: '', sizeBytes: sizeBytes);
    _fromInbox = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> _myUploads = const [];
  bool _loadingUploads = false;
  String? _uploadsError;

  List<Map<String, dynamic>> get myUploads => _myUploads;
  bool get loadingUploads => _loadingUploads;
  String? get uploadsError => _uploadsError;

  /// GET /api/uploads/mine — danh sách file đã tải lên của tài khoản này.
  Future<void> loadMyUploads() async {
    _loadingUploads = true;
    _uploadsError = null;
    notifyListeners();
    try {
      final rows = await _api.getList('/api/uploads/mine');
      _myUploads = rows.whereType<Map>().map((row) => row.cast<String, dynamic>()).toList();
    } catch (error) {
      _uploadsError = error.toString();
    } finally {
      _loadingUploads = false;
      notifyListeners();
    }
  }

  UploadStatus get status => _status;
  String? get selectedFileName => _selectedFileName;
  String? get selectedFilePath => _selectedFilePath;
  int? get selectedFileSizeKb => _selectedFileSizeKb;
  String? get selectedFileExtension => _selectedFileExtension;
  String? get errorMessage => _errorMessage;
  String get quizTitle => _quizTitle;
  String get quizSubject => _quizSubject;
  String get quizDescription => _quizDescription;
  int get lastUploadQuestionCount => _lastUploadQuestionCount;
  String? get lastUploadMessage => _lastUploadMessage;
  String? get lastParsingMode => _lastParsingMode;
  List<String> get lastUploadWarnings => List.unmodifiable(_lastUploadWarnings);
  bool get hasFile => _selectedFileName != null;
  String get fileSizeDisplay {
    if (_selectedFileSizeKb == null) return '';
    return _selectedFileSizeKb! < 1024 ? '$_selectedFileSizeKb KB' : '${(_selectedFileSizeKb! / 1024).toStringAsFixed(1)} MB';
  }

  void onFileSelected({required String name, required String path, Uint8List? bytes, required int sizeBytes}) {
    _selectedFileName = name;
    _selectedFilePath = path;
    _selectedFileBytes = bytes;
    _fromInbox = false;
    _selectedFileSizeKb = sizeBytes ~/ 1024;
    _selectedFileExtension = name.split('.').last.toLowerCase();
    _quizTitle = name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
    _status = UploadStatus.fileSelected;
    _errorMessage = null;
    notifyListeners();
  }

  void removeFile() {
    _fromInbox = false;
    _selectedFileName = null;
    _selectedFilePath = null;
    _selectedFileBytes = null;
    _selectedFileSizeKb = null;
    _selectedFileExtension = null;
    _status = UploadStatus.idle;
    _errorMessage = null;
    notifyListeners();
  }

  void updateTitle(String value) { _quizTitle = value; notifyListeners(); }
  void updateSubject(String value) { _quizSubject = value; notifyListeners(); }
  void updateDescription(String value) { _quizDescription = value; notifyListeners(); }

  Future<Quiz?> uploadQuiz() async {
    if (!hasFile || (!_fromInbox && (_selectedFilePath?.isEmpty ?? true) && _selectedFileBytes == null)) {
      _status = UploadStatus.error;
      _errorMessage = 'Không đọc được nội dung file. Hãy chọn lại file rồi thử lại.';
      notifyListeners();
      return null;
    }
    if (_quizTitle.trim().isEmpty || _quizSubject.trim().isEmpty) {
      _status = UploadStatus.error;
      _errorMessage = 'Vui lòng nhập tên bài và môn học.';
      notifyListeners();
      return null;
    }

    _status = UploadStatus.uploading;
    _errorMessage = null;
    notifyListeners();
    try {
      final json = _fromInbox
          ? await _api.post('/api/uploads/inbox/import', {
              'file_name': _selectedFileName,
              'title': _quizTitle.trim(),
              'subject': _quizSubject.trim(),
              'description': _quizDescription.trim(),
            })
          : await _api.uploadQuizFile(
              path: _selectedFilePath,
              bytes: _selectedFileBytes,
              fileName: _selectedFileName!,
              title: _quizTitle.trim(),
              subject: _quizSubject.trim(),
              description: _quizDescription.trim(),
            );
      _lastUploadQuestionCount = (json['questions_count'] as num?)?.toInt() ?? 0;
      _lastUploadMessage = json['message']?.toString();
      _lastParsingMode = json['parsing_mode']?.toString();
      _lastUploadWarnings = (json['warnings'] as List? ?? const []).map((value) => value.toString()).toList();
      final quizId = json['quiz_id']?.toString() ?? 'draft_${DateTime.now().millisecondsSinceEpoch}';
      final rawQuiz = await _api.get('/api/quizzes/$quizId');
      final quiz = Quiz.fromJson(rawQuiz);
      _status = UploadStatus.success;
      notifyListeners();
      unawaited(loadMyUploads());
      unawaited(loadInbox());
      return quiz;
    } catch (error) {
      _status = UploadStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  void reset() {
    _fromInbox = false;
    _status = UploadStatus.idle;
    _selectedFileName = null;
    _selectedFilePath = null;
    _selectedFileBytes = null;
    _selectedFileSizeKb = null;
    _selectedFileExtension = null;
    _errorMessage = null;
    _quizTitle = '';
    _quizSubject = '';
    _quizDescription = '';
    _lastUploadQuestionCount = 0;
    _lastUploadMessage = null;
    _lastParsingMode = null;
    _lastUploadWarnings = const [];
    notifyListeners();
  }
}
