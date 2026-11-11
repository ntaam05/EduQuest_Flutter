import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kết nối tới Auth, RPC và Edge Functions của cùng một dự án Supabase.
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  static const _projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _setupMessage =
      'Bản cài chưa được cấu hình Supabase. Hãy liên hệ người gửi APK.';

  final loggedIn = ValueNotifier(false);
  final sessionId = ValueNotifier(0);
  String? sessionMessage;
  Map<String, dynamic>? _sessionProfile;
  Map<String, dynamic>? get sessionProfile => _sessionProfile;
  bool get isAuthenticated => loggedIn.value;
  SupabaseClient? _client;
  SharedPreferences? _preferences;
  String? _profileKey;
  Future<void>? _initialization;
  String? _setupError;

  SupabaseClient get supabase =>
      _client ?? (throw ApiException(_setupError ?? _setupMessage, 0));

  Future<void> initialize({
    String url = _projectUrl,
    String publishableKey = _publishableKey,
    http.Client? httpClient,
  }) =>
      _initialization ??= _initialize(url, publishableKey, httpClient);

  Future<void> _initialize(
      String url, String key, http.Client? httpClient) async {
    final uri = Uri.tryParse(url.trim());
    final local = !kReleaseMode &&
        uri?.scheme == 'http' &&
        (uri?.host == '127.0.0.1' ||
            uri?.host == 'localhost' ||
            uri?.host == '10.0.2.2');
    if (uri == null ||
        uri.host.isEmpty ||
        (!local && uri.scheme != 'https') ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        !_validPublishableKey(key.trim())) {
      sessionMessage = _setupError = _setupMessage;
      return;
    }
    try {
      final origin = uri.origin;
      _profileKey = 'eduquest.profile.${Uri.encodeComponent(origin)}';
      _preferences = await SharedPreferences.getInstance();
      final result = await Supabase.initialize(
        url: origin,
        publishableKey: key.trim(),
        httpClient: httpClient,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
      );
      _client = result.client;
      _publishUser(_client!.auth.currentSession?.user);
      _client!.auth.onAuthStateChange.listen(
        (event) => _publishUser(event.session?.user),
        onError: (Object _) {
          // The SDK retries transient network errors while refreshing the session.
        },
      );
    } catch (_) {
      sessionMessage = _setupError =
          'Không khởi tạo được Supabase. Hãy kiểm tra cấu hình của bản cài.';
    }
  }

  static bool _validPublishableKey(String key) {
    if (key.startsWith('sb_publishable_') &&
        key.length > 'sb_publishable_'.length) return true;
    try {
      final segments = key.split('.');
      if (segments.length != 3) return false;
      final data = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))));
      return data is Map && data['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  void _publishUser(User? user) {
    if (user?.id == _sessionProfile?['id']) return;
    if (user == null) {
      _sessionProfile = null;
      loggedIn.value = false;
    } else {
      final name = user.userMetadata?['name']?.toString().trim();
      Map<String, dynamic>? cached;
      try {
        final raw = _preferences?.getString(_profileKey!);
        final value = raw == null ? null : jsonDecode(raw);
        if (value is Map<String, dynamic> &&
            value['id'] == user.id &&
            value['name'] is String) {
          cached = value;
        }
      } on FormatException {
        // A damaged cache is ignored. Auth metadata already contains the registered name.
      }
      _sessionProfile = Map.unmodifiable(cached ??
          {
            'id': user.id,
            'name': name == null || name.isEmpty ? 'Người học' : name,
          });
      sessionMessage = null;
      loggedIn.value = true;
    }
    sessionId.value++;
  }

  Future<void> cacheProfile(Map<String, dynamic> profile) async {
    if (profile['id'] != _sessionProfile?['id']) return;
    _sessionProfile = Map.unmodifiable(profile);
    try {
      await _preferences?.setString(_profileKey!, jsonEncode(profile));
    } catch (_) {
      // The in-memory profile remains available if the local cache cannot be saved.
    }
  }

  Future<void> login(String email, String password) async {
    await initialize();
    final result = await _request(() => supabase.auth
        .signInWithPassword(email: email.trim(), password: password));
    _publishUser(result.session?.user);
  }

  /// Returns false when Supabase requires the user to confirm their email first.
  Future<bool> register(
      {required String name,
      required String email,
      required String password}) async {
    await initialize();
    final cleanedName = name.trim();
    if (cleanedName.isEmpty || cleanedName.runes.length > 120) {
      throw const ApiException('Họ tên cần có từ 1 đến 120 ký tự.', 400);
    }
    final result = await _request(() => supabase.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'name': cleanedName},
        ));
    if (result.session == null) return false;
    _publishUser(result.session!.user);
    return true;
  }

  Future<void> changePassword(String current, String next) async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) throw const ApiException('Bạn chưa đăng nhập.', 401);
    if (current == next)
      throw const ApiException(
          'Mật khẩu mới phải khác mật khẩu hiện tại.', 400);
    final revision = sessionId.value;
    await _request(() =>
        supabase.auth.signInWithPassword(email: email, password: current));
    _checkRevision(revision);
    await _request(
        () => supabase.auth.updateUser(UserAttributes(password: next)));
  }

  Future<void> logout() async {
    await _request(() => supabase.auth.signOut(scope: SignOutScope.local));
    _publishUser(null);
    if (_sessionProfile == null) await _preferences?.remove(_profileKey!);
  }

  Future<Map<String, dynamic>> data(String action,
          [Map<String, dynamic> input = const {}]) async =>
      _asMap(await _rpc('eduquest_data', action, input));

  Future<List<dynamic>> dataList(String action) async =>
      (await _rpc('eduquest_data', action, const {})) as List<dynamic>;

  Future<Map<String, dynamic>> room(String action,
          [Map<String, dynamic> input = const {}]) async =>
      _asMap(await _rpc('eduquest_rooms', action, input));

  Future<List<dynamic>> roomList() async =>
      (await _rpc('eduquest_rooms', 'list', const {})) as List<dynamic>;

  Future<dynamic> _rpc(
      String rpc, String action, Map<String, dynamic> input) async {
    final revision = sessionId.value;
    final result = await _request(() async => supabase
        .rpc<dynamic>(rpc, params: {'p_action': action, 'p_input': input}));
    _checkRevision(revision);
    return result;
  }

  Future<void> deleteQuiz(String quizId) async {
    final revision = sessionId.value;
    await _request(() => supabase.functions.invoke(
          'eduquest-upload',
          method: HttpMethod.delete,
          queryParameters: {'quiz_id': quizId},
        ));
    _checkRevision(revision);
  }

  Future<Map<String, dynamic>> uploadQuizFile({
    String? path,
    Uint8List? bytes,
    required String fileName,
    required String title,
    required String subject,
    required String description,
  }) async {
    final revision = sessionId.value;
    final http.MultipartFile file;
    if (bytes != null) {
      file = http.MultipartFile.fromBytes('file', bytes, filename: fileName);
    } else if (path != null && path.isNotEmpty) {
      file =
          await http.MultipartFile.fromPath('file', path, filename: fileName);
    } else {
      throw const ApiException('Không đọc được nội dung file đã chọn.', 400);
    }
    _checkRevision(revision);
    final result = await _request(
        () => supabase.functions.invoke(
              'eduquest-upload',
              body: {
                'title': title,
                'subject': subject,
                'description': description
              },
              files: [file],
            ),
        timeout: const Duration(seconds: 90));
    _checkRevision(revision);
    return _asMap(result.data);
  }

  void _checkRevision(int revision) {
    if (revision != sessionId.value)
      throw const ApiException('Phiên đăng nhập đã thay đổi.', 401);
  }

  Future<T> _request<T>(Future<T> Function() send,
      {Duration timeout = const Duration(seconds: 25)}) async {
    try {
      return await send().timeout(timeout);
    } on AuthException catch (error) {
      final message = switch (error.code) {
        'invalid_credentials' => 'Email hoặc mật khẩu không đúng.',
        'email_not_confirmed' => 'Hãy xác nhận email trước khi đăng nhập.',
        'user_already_exists' => 'Email đã được sử dụng.',
        'weak_password' => 'Mật khẩu chưa đáp ứng yêu cầu bảo mật.',
        _ => error.message,
      };
      throw ApiException(message, int.tryParse(error.statusCode ?? '') ?? 400);
    } on PostgrestException catch (error) {
      final code = error.code ?? '';
      throw ApiException(error.message,
          code.startsWith('PT') ? int.tryParse(code.substring(2)) ?? 400 : 400);
    } on FunctionException catch (error) {
      final details = error.details;
      throw ApiException(
        details is Map && details['message'] is String
            ? details['message'] as String
            : 'Không hoàn tất được yêu cầu tài liệu (HTTP ${error.status}).',
        error.status,
      );
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi chậm. Vui lòng thử lại.', 0);
    } on http.ClientException {
      throw const ApiException(
          'Không kết nối được EduQuest. Hãy kiểm tra Internet và thử lại.', 0);
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    throw const FormatException(
        'Supabase không trả về dữ liệu EduQuest hợp lệ.');
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
