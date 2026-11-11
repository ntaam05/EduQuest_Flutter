// Upload file thật lên backend; server lưu tệp và metadata.
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/quiz.dart';
import '../services/api_client.dart';

enum UploadStatus { idle, fileSelected, uploading, success, error }

class UploadProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;
  final int _sessionId = ApiClient.instance.sessionId.value;
  bool _disposed = false;

  bool get _active => !_disposed && _sessionId == _api.sessionId.value;

  @override
  void notifyListeners() {
    if (_active) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
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
  List<Map<String, dynamic>> _myUploads = const [];
  bool _loadingUploads = false;
  String? _uploadsError;

  List<Map<String, dynamic>> get myUploads => _myUploads;
  bool get loadingUploads => _loadingUploads;
  String? get uploadsError => _uploadsError;

  /// danh sách file đã tải lên của tài khoản này.
  Future<void> loadMyUploads() async {
    _loadingUploads = true;
    _uploadsError = null;
    notifyListeners();
    try {
      final rows = await _api.dataList('upload_list');
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
    _selectedFileSizeKb = sizeBytes ~/ 1024;
    _selectedFileExtension = name.split('.').last.toLowerCase();
    _quizTitle = name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
    _status = UploadStatus.fileSelected;
    _errorMessage = null;
    notifyListeners();
  }

  void removeFile() {
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
    if (!hasFile || ((_selectedFilePath?.isEmpty ?? true) && _selectedFileBytes == null)) {
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
      final json = await _api.uploadQuizFile(
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
      final quiz = Quiz.fromJson((json['quiz'] as Map).cast<String, dynamic>());
      _status = UploadStatus.success;
      notifyListeners();
      if (_active) unawaited(loadMyUploads());
      return quiz;
    } catch (error) {
      _status = UploadStatus.error;
      _errorMessage = error.toString();
      notifyListeners();
      return null;
    }
  }

  void reset() {
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
