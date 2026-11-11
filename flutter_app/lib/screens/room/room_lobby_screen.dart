import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/room.dart';
import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../../routes/app_router.dart';
import '../../services/room_realtime_client.dart';
import '../../theme/app_colors.dart';

class RoomLobbyScreen extends StatefulWidget {
  const RoomLobbyScreen({super.key, required this.roomCode});
  final String roomCode;

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  Timer? _pollTimer;
  final RoomRealtimeClient _realtime = RoomRealtimeClient();
  String? _connectedRoomId;
  bool _starting = false;
  bool _refreshing = false;
  bool _initialLoad = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_realtime.dispose());
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _refreshing) return;
    _refreshing = true;
    try {
      final roomProvider = context.read<RoomProvider>();
      final current = roomProvider.currentRoom;
      final knownId = _connectedRoomId ??
          (current != null && current.code == widget.roomCode.toUpperCase() ? current.id : null);
      final room = knownId != null
          ? await roomProvider.refreshRoomById(knownId)
          : await roomProvider.loadRoomByCode(widget.roomCode);
      if (!mounted) return;
      setState(() {
        _initialLoad = false;
        _loadError = room == null ? roomProvider.errorMessage : null;
      });
      if (room == null) return;
      if (room.status != RoomStatus.waiting) {
        context.go(AppRoutes.roomGamePath(room.code));
        return;
      }
      if (_connectedRoomId == null) {
        _connectedRoomId = room.id;
        _realtime.subscribe(room.id, () => unawaited(_refresh()));
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    final ok = await context.read<RoomProvider>().startGame();
    if (!mounted) return;
    setState(() => _starting = false);
    if (ok) {
      final room = context.read<RoomProvider>().currentRoom;
      if (room != null) context.go(AppRoutes.roomGamePath(room.code));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.read<RoomProvider>().errorMessage ?? 'Không thể bắt đầu trận.'),
      ));
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoomProvider>();
    final room = provider.currentRoom?.code == widget.roomCode.toUpperCase() ? provider.currentRoom : null;
    final me = context.watch<ProfileProvider>().user;
    final isHost = room != null && room.host.id == me.id;
    final theme = Theme.of(context);

    if (room == null && _initialLoad) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phòng ôn tập')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(_loadError ?? 'Không tìm thấy phòng ${widget.roomCode}.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _refresh, child: const Text('Thử lại')),
          ]),
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng ôn tập'),
        actions: [IconButton(tooltip: 'Làm mới', onPressed: _refresh, icon: const Icon(Icons.refresh))],
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MÃ PHÒNG', style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 2, color: AppColors.primary)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text(room.code, style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 4))),
                  IconButton(
                    tooltip: 'Chia sẻ mã phòng',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: room.code));
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép mã phòng. Gửi mã này cho bạn bè để cùng tham gia.')));
                    },
                    icon: const Icon(Icons.ios_share),
                  ),
                ]),
                const Divider(height: 28),
                Text(room.quiz.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('${room.players.length}/${room.maxPlayers} người chơi', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('Mỗi câu có ${room.questionDurationSeconds} giây. Đúng càng nhanh, điểm càng cao.', style: theme.textTheme.bodyMedium),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Text('Người chơi', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          ...room.players.map((player) => Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(player.avatarEmoji ?? '👤')),
              title: Text(player.name),
              subtitle: player.id == room.host.id ? const Text('Chủ phòng') : null,
              trailing: player.id == room.host.id ? const Icon(Icons.workspace_premium, color: AppColors.warning) : const Icon(Icons.check_circle_outline),
            ),
          )),
          const SizedBox(height: 20),
          if (provider.errorMessage != null) Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(provider.errorMessage!, style: const TextStyle(color: AppColors.error)),
          ),
          if (isHost)
            FilledButton.icon(
              onPressed: _starting || room.quiz.questions.isEmpty ? null : _start,
              icon: _starting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_rounded),
              label: Text(_starting ? 'Đang bắt đầu...' : 'Bắt đầu ôn tập'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            )
          else
            const Card(child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [Icon(Icons.hourglass_top, color: AppColors.primary), SizedBox(width: 12), Expanded(child: Text('Đang chờ chủ phòng bắt đầu. Màn hình sẽ tự chuyển sang câu hỏi khi trận bắt đầu.'))]),
            )),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await context.read<RoomProvider>().leaveRoom();
              if (context.mounted) context.go(AppRoutes.rooms);
            },
            icon: const Icon(Icons.exit_to_app), label: const Text('Rời phòng'),
          ),
        ]),
      ),
    );
  }
}
