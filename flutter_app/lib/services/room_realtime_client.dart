import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';
import 'api_client.dart';

typedef RoomEventHandler = void Function(Map<String, dynamic> payload);

/// One SignalR connection per room screen. JWT is supplied using access_token on the hub URL.
class RoomRealtimeClient {
  RoomRealtimeClient({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;
  HubConnection? _connection;
  final Map<String, List<RoomEventHandler>> _handlers = {};
  String? _joinedRoomId;
  bool _disposed = false;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  void on(String eventName, RoomEventHandler handler) {
    (_handlers[eventName] ??= []).add(handler);
  }

  Future<void> connect() async {
    if (_disposed) throw StateError('RoomRealtimeClient đã đóng.');
    if (_connection != null && _connection!.state != HubConnectionState.Disconnected) return;
    if (_connection != null) {
      try { await _connection!.stop(); } catch (_) {}
      _connection = null;
    }
    await _api.initialize();
    final base = _api.baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final connection = HubConnectionBuilder()
        .withUrl(
          '$base/hubs/rooms',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => await _api.accessToken,
          ),
        )
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
        .build();

    for (final eventName in <String>[
      'RoomUpdated',
      'QuestionStarted',
      'RoundProgress',
      'QuestionResult',
      'GameFinished',
    ]) {
      connection.on(eventName, (arguments) {
        if (arguments == null || arguments.isEmpty || arguments.first is! Map) return;
        final raw = arguments.first as Map;
        final payload = raw.map((key, value) => MapEntry(key.toString(), value));
        for (final handler in List<RoomEventHandler>.from(_handlers[eventName] ?? const [])) {
          handler(payload);
        }
      });
    }
    connection.onreconnected(({String? connectionId}) {
      final roomId = _joinedRoomId;
      if (!_disposed && roomId != null) unawaited(_rejoinAfterReconnect(connection, roomId));
    });
    connection.onclose(({Exception? error}) {});
    _connection = connection;
    await connection.start();
  }

  Future<void> _rejoinAfterReconnect(HubConnection connection, String roomId) async {
    try {
      // SignalR groups are scoped to a connection ID; rejoin after reconnect.
      await connection.invoke('JoinRoom', args: <Object>[roomId]);
    } catch (_) {
      // REST polling in RoomGameScreen remains the recovery path if this fails.
    }
  }

  Future<Map<String, dynamic>> joinRoom(String roomId) async {
    _joinedRoomId = roomId;
    await connect();
    final result = await _connection!.invoke('JoinRoom', args: <Object>[roomId]);
    if (result is Map) return result.map((key, value) => MapEntry(key.toString(), value));
    throw const FormatException('Server không trả trạng thái phòng hợp lệ.');
  }

  Future<Map<String, dynamic>> submitAnswer({
    required String roomId,
    required int questionId,
    required int selectedAnswerIndex,
  }) async {
    await connect();
    final result = await _connection!.invoke('SubmitAnswer', args: <Object>[roomId, questionId, selectedAnswerIndex]);
    if (result is Map) return result.map((key, value) => MapEntry(key.toString(), value));
    return <String, dynamic>{'accepted': true};
  }

  Future<void> leaveRoom(String roomId) async {
    if (_joinedRoomId == roomId) _joinedRoomId = null;
    final connection = _connection;
    if (connection != null && connection.state == HubConnectionState.Connected) {
      try { await connection.invoke('LeaveRoom', args: <Object>[roomId]); } catch (_) { /* disconnect below */ }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      try {
        if (connection.state != HubConnectionState.Disconnected) await connection.stop();
      } catch (_) {}
    }
    _handlers.clear();
    _joinedRoomId = null;
  }
}
