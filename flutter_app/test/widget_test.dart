import 'dart:async';
import 'dart:convert';

import 'package:doanmon_eduquest/main.dart';
import 'package:doanmon_eduquest/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> authUser(String id, String name, String email) => {
      'id': id,
      'email': email,
      'user_metadata': {'name': name},
      'app_metadata': {
        'provider': 'email',
        'providers': ['email']
      },
      'created_at': '2026-01-01T00:00:00Z',
    };

Map<String, dynamic> authSession(Map<String, dynamic> user) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiresAt =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000;
  final claims =
      encode({'exp': expiresAt, 'sub': user['id'], 'role': 'authenticated'});
  return {
    'user': user,
    'access_token': "${encode({'alg': 'HS256', 'typ': 'JWT'})}.$claims.dGVzdA",
    'token_type': 'bearer',
    'expires_in': 3600,
    'refresh_token': 'mock-refresh-${user['id']}',
  };
}

void main() {
  testWidgets(
      'Tên đúng ngay khi khôi phục phiên, đăng ký và đăng nhập qua Supabase Auth',
      (tester) async {
    const url = 'https://test.supabase.co';
    final restored = authUser('10000000-0000-4000-8000-000000000001',
        'Hà Minh Anh', 'anh@example.com');
    final registered = authUser('10000000-0000-4000-8000-000000000002',
        'Trần Bảo Ngọc', 'ngoc@example.com');
    final signedIn = authUser('10000000-0000-4000-8000-000000000003',
        'Lê Quang Minh', 'minh@example.com');
    SharedPreferences.setMockInitialValues({
      'sb-test-auth-token': jsonEncode(authSession(restored)),
    });
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final profileRequest = Completer<void>();
    http.Response jsonResponse(Object data) => http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
    var current = restored;
    var confirmationRequired = false;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/auth/v1/signup':
          final payload = jsonDecode(request.body);
          if (confirmationRequired) return jsonResponse(registered);
          expect(payload['data']['name'], 'Trần Bảo Ngọc');
          current = registered;
          return jsonResponse(authSession(current));
        case '/auth/v1/token':
          current = signedIn;
          return jsonResponse(authSession(current));
        case '/auth/v1/logout':
          return http.Response('', 204);
        case '/rest/v1/rpc/eduquest_data':
          final action = jsonDecode(request.body)['p_action'];
          if (action == 'profile_get') {
            final responseUser = current;
            await profileRequest.future;
            return jsonResponse({
              'id': responseUser['id'],
              'name': responseUser['user_metadata']['name']
            });
          }
          return jsonResponse(action == 'quiz_list' ? [] : {});
        case '/rest/v1/rpc/eduquest_rooms':
          return jsonResponse([]);
        default:
          fail('Unexpected request ${request.url.path}');
      }
    });
    final api = ApiClient.instance;
    await tester.runAsync(() => api.initialize(
          url: url,
          publishableKey: 'sb_publishable_testing',
          httpClient: client,
        ));
    addTearDown(() => Supabase.instance.dispose());
    await tester.pumpWidget(EduQuestStartup(ready: Future.value()));
    await tester.pumpAndSettle();
    expect(find.text('Hà Minh Anh'), findsOneWidget);

    Future<void> logout() async {
      await tester.runAsync(api.logout);
      await tester.pumpAndSettle();
    }

    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 70; i++) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(finder, findsOneWidget);
    }

    Future<void> signup() async {
      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '  Trần Bảo Ngọc  ');
      await tester.enterText(fields.at(1), 'ngoc@example.com');
      await tester.enterText(fields.at(2), 'Password123');
      await tester.enterText(fields.at(3), 'Password123');
      await tester.tap(find.text('Đăng ký'));
      await tester.pump();
    }

    await logout();
    await signup();
    await waitFor(find.text('Trần Bảo Ngọc'));
    expect(find.text('Trần Bảo Ngọc'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsNothing);
    expect(find.text('Hà Minh Anh'), findsNothing);

    await logout();
    confirmationRequired = true;
    await signup();
    await waitFor(find.textContaining('Hãy mở email xác nhận tài khoản'));
    expect(
        find.textContaining('Hãy mở email xác nhận tài khoản'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'minh@example.com');
    await tester.enterText(fields.at(1), 'Password123');
    await tester.tap(find.text('Đăng nhập'));
    await waitFor(find.text('Lê Quang Minh'));
    expect(find.text('Lê Quang Minh'), findsOneWidget);
    expect(find.text('Trần Bảo Ngọc'), findsNothing);

    profileRequest.complete();
    await tester.pumpAndSettle();
    expect(find.text('Lê Quang Minh'), findsOneWidget);
    await logout();
    expect(tester.takeException(), isNull);
  });
}
