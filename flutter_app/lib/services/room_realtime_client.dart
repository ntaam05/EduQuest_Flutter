import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_client.dart';

/// Realtime only signals that a room changed. Personal answers come from a protected RPC.
class RoomRealtimeClient {
  static int _nextSubscription = 0;
  RealtimeChannel? _channel;

  void subscribe(String roomId, void Function() onChanged) {
    if (_channel != null) return;
    _channel = ApiClient.instance.supabase
        .channel('eduquest-room-$roomId-${_nextSubscription++}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'eduquest_room_updates',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId),
          callback: (_) => onChanged(),
        )
        .subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) onChanged();
    });
  }

  Future<void> dispose() async {
    final channel = _channel;
    _channel = null;
    if (channel != null)
      await ApiClient.instance.supabase.removeChannel(channel);
  }
}
