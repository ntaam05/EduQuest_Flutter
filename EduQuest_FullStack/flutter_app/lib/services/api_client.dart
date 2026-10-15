import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Client REST dùng chung của EduQuest.
/// Đổi API_BASE_URL qua --dart-define nếu chạy trên điện thoại thật.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _tokenKey = 'eduquest.token';

  String? _token;
  bool _initialized = false;
  Future<void>? _initializing;

  /// true khi đang có phiên đăng nhập (router lắng nghe để chuyển giữa màn Đăng nhập và Trang chủ).
  final ValueNotifier<bool> loggedIn = ValueNotifier<bool>(false);

  /// Tăng mỗi lần đăng nhập/đăng xuất để dựng lại toàn bộ Provider (xóa sạch dữ liệu của phiên cũ).
  final ValueNotifier<int> sessionId = ValueNotifier<int>(0);

  /// Thông báo hiển thị ở màn đăng nhập (VD: phiên đã hết hạn). Màn đăng nhập đọc rồi xóa.
  String? sessionMessage;

  String get baseUrl {
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return _configuredBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5080';
    return 'http://127.0.0.1:5080';
  }

  bool get isAuthenticated => _token != null;

  Future<String> get accessToken async {
    await initialize();
    final value = _token;
    if (value == null || value.isEmpty) throw const ApiException('Bạn chưa đăng nhập.', 401);
    return value;
  }

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _connect().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _connect() async {
    Object? lastError;
    // Chờ backend khởi động (kịch bản one-click cũng kiểm tra health trước).
    for (var attempt = 0; attempt < 30; attempt++) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/')).timeout(
          const Duration(seconds: 2),
        );
        if (response.statusCode == 200) {
          final dynamic health = jsonDecode(response.body);
          if (health is Map && health['name'] == 'EduQuest API') {
            await _restoreSession();
            _initialized = true;
            return;
          }
          lastError = const ApiException('Cổng 5080 không phản hồi đúng dịch vụ EduQuest API.', 0);
        } else {
          lastError = ApiException('Backend trả về HTTP ${response.statusCode}.', response.statusCode);
        }
      } catch (error) {
        lastError = error;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw ApiException(
      'Không kết nối được EduQuest API tại $baseUrl. Hãy chạy backend trước và kiểm tra cổng 5080. Chi tiết: $lastError',
      0,
    );
  }

  /// Đọc token đã lưu và kiểm tra còn hiệu lực bằng GET /api/auth/me.
  Future<void> _restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_tokenKey);
    if (stored == null || stored.isEmpty) {
      _token = null;
      loggedIn.value = false;
      return;
    }
    _token = stored;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $stored'},
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode == 401) {
        await _endSession(message: 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.', bump: false);
        return;
      }
    } catch (_) {
      // Mất mạng thoáng qua: vẫn giữ token, lỗi (nếu có) sẽ hiện khi gọi API.
    }
    loggedIn.value = true;
  }

  /// POST /api/auth/login — lưu token và trả về thông tin user.
  Future<Map<String, dynamic>> login(String email, String password) {
    return _authenticate('/api/auth/login', {'email': email.trim(), 'password': password});
  }

  /// POST /api/auth/register — tạo tài khoản và đăng nhập luôn.
  Future<Map<String, dynamic>> register({required String name, required String email, required String password}) {
    return _authenticate('/api/auth/register', {'name': name.trim(), 'email': email.trim(), 'password': password});
  }

  Future<Map<String, dynamic>> _authenticate(String path, Map<String, dynamic> body) async {
    await initialize();
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _decodeValidationMessage(response.body) ?? 'Không thể xác thực (HTTP ${response.statusCode}).',
        response.statusCode,
      );
    }
    final data = _asMap(jsonDecode(response.body));
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw const ApiException('Máy chủ không trả về token đăng nhập.', 500);
    }
    _token = token;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
    sessionMessage = null;
    loggedIn.value = true;
    sessionId.value++;
    return _asMap(data['user']);
  }

  /// Đăng xuất: xóa token, router chuyển về màn Đăng nhập, Provider được dựng lại.
  Future<void> logout() => _endSession();

  Future<void> _endSession({String? message, bool bump = true}) async {
    final wasLoggedIn = loggedIn.value || _token != null;
    _token = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    sessionMessage = message;
    loggedIn.value = false;
    // Chỉ dựng lại Provider nếu trước đó thực sự đang đăng nhập (tránh vòng lặp khi nhiều request cùng 401).
    if (bump && wasLoggedIn) sessionId.value++;
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _send('GET', path);
    return _asMap(response);
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _send('GET', path);
    if (response is List) return response;
    throw const FormatException('API không trả về danh sách JSON như dự kiến.');
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final response = await _send('POST', path, body: body);
    if (response == null) return <String, dynamic>{};
    return _asMap(response);
  }

  /// POST với thời gian chờ tùy chỉnh (VD: chờ người dùng chọn file trên máy tính).
  Future<Map<String, dynamic>> postWithTimeout(String path, {Map<String, dynamic>? body, required Duration timeout}) async {
    final response = await _send('POST', path, body: body, timeout: timeout);
    if (response == null) return <String, dynamic>{};
    return _asMap(response);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final response = await _send('PUT', path, body: body);
    return _asMap(response);
  }

  Future<void> delete(String path) async {
    await _send('DELETE', path);
  }

  Future<Map<String, dynamic>> uploadQuizFile({
    String? path,
    Uint8List? bytes,
    required String fileName,
    required String title,
    required String subject,
    required String description,
  }) async {
    await initialize();
    if (_token == null) throw const ApiException('Bạn chưa đăng nhập.', 401);
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/uploads/quiz-file'));
    request.headers['Authorization'] = 'Bearer $_token';
    request.fields['title'] = title;
    request.fields['subject'] = subject;
    request.fields['description'] = description;
    // Web không có đường dẫn file nên dùng bytes; desktop/mobile đọc trực tiếp từ đường dẫn.
    if (bytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    } else if (path != null && path.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('file', path, filename: fileName));
    } else {
      throw const ApiException('Không đọc được nội dung file đã chọn.', 400);
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) {
      await _endSession(message: 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.');
      throw const ApiException('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.', 401);
    }
    final dynamic decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_decodeMessage(response.body) ?? 'Upload thất bại (HTTP ${response.statusCode}).', response.statusCode);
    }
    return _asMap(decoded);
  }

  Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body, Duration? timeout}) async {
    await initialize();
    if (_token == null) throw const ApiException('Bạn chưa đăng nhập.', 401);
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Accept': 'application/json'};
    if (_token != null) headers['Authorization'] = 'Bearer $_token';
    if (body != null) headers['Content-Type'] = 'application/json';

    late http.Response response;
    final effectiveTimeout = timeout ?? const Duration(seconds: 25);
    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers).timeout(effectiveTimeout);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: body == null ? null : jsonEncode(body)).timeout(effectiveTimeout);
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: jsonEncode(body)).timeout(effectiveTimeout);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers).timeout(effectiveTimeout);
        break;
      default:
        throw ArgumentError('HTTP method không được hỗ trợ: $method');
    }

    if (response.statusCode == 401) {
      await _endSession(message: 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.');
      throw const ApiException('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.', 401);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _decodeMessage(response.body) ?? 'Yêu cầu API thất bại (HTTP ${response.statusCode}).',
        response.statusCode,
      );
    }
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry(key.toString(), value));
    throw const FormatException('API không trả về object JSON như dự kiến.');
  }

  /// Ưu tiên message của API; với lỗi validation mặc định của ASP.NET lấy câu lỗi đầu tiên.
  static String? _decodeValidationMessage(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map && value['message'] != null) return value['message'].toString();
      if (value is Map && value['errors'] is Map) {
        for (final entry in (value['errors'] as Map).values) {
          if (entry is List && entry.isNotEmpty) return entry.first.toString();
        }
      }
    } catch (_) {}
    return _decodeMessage(body);
  }

  static String? _decodeMessage(String body) {
    try {
      final value = jsonDecode(body);
      if (value is Map) {
        return (value['message'] ?? value['title'] ?? value['detail'])?.toString();
      }
    } catch (_) {
      if (body.trim().isNotEmpty) return body.trim();
    }
    return null;
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
