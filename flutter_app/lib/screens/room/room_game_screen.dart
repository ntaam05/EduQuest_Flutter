import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/profile_provider.dart';
import '../../providers/room_provider.dart';
import '../../routes/app_router.dart';
import '../../services/api_client.dart';
import '../../services/room_realtime_client.dart';
import '../../services/sound_service.dart';
import '../../theme/app_colors.dart';

class RoomGameScreen extends StatefulWidget {
  const RoomGameScreen({super.key, required this.roomCode});
  final String roomCode;

  @override
  State<RoomGameScreen> createState() => _RoomGameScreenState();
}

class _RoomGameScreenState extends State<RoomGameScreen> {
  final RoomRealtimeClient _realtime = RoomRealtimeClient();
  final ApiClient _api = ApiClient.instance;
  Timer? _clockTimer;
  Timer? _pollTimer;
  String? _roomId;
  String _mode = 'loading';
  Map<String, dynamic>? _questionEvent;
  Map<String, dynamic>? _result;
  List<dynamic> _leaderboard = const [];
  int _roundNumber = 0;
  int _answeredCount = 0;
  int _totalPlayers = 0;
  int _secondsLeft = 25;
  int? _selectedIndex;
  bool _hasAnswered = false;
  bool _submitting = false;
  bool _initializing = true;
  String? _error;
  bool _refreshing = false;
  bool _refreshPending = false;
  Duration _serverOffset = Duration.zero;
  bool _soundOn = SoundService.instance.enabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
    _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _updateClock());
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refreshSnapshot());
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pollTimer?.cancel();
    unawaited(SoundService.instance.stopAll());
    unawaited(_realtime.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    final provider = context.read<RoomProvider>();
    try {
      final room = await provider.loadRoomByCode(widget.roomCode);
      if (!mounted) return;
      if (room == null) throw Exception(provider.errorMessage ?? 'Không tìm thấy phòng.');
      _roomId = room.id;
      _realtime.subscribe(room.id, () => unawaited(_refreshSnapshot()));
      await _refreshSnapshot();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _refreshSnapshot() async {
    if (!mounted || _roomId == null || _mode == 'finished') return;
    if (_refreshing) {
      _refreshPending = true;
      return;
    }
    _refreshing = true;
    try {
      final started = DateTime.now().toUtc();
      final snapshot = await context.read<RoomProvider>().loadGameState(_roomId!);
      if (mounted) {
        final serverTime = DateTime.tryParse(snapshot['server_time']?.toString() ?? '');
        if (serverTime != null) {
          final halfRtt = DateTime.now().toUtc().difference(started).inMicroseconds ~/ 2;
          _serverOffset = serverTime.toUtc().difference(started.add(Duration(microseconds: halfRtt)));
        }
        _applySnapshot(snapshot);
      }
    } catch (error) {
      if (mounted && _error == null) setState(() => _error = error.toString());
    } finally {
      _refreshing = false;
      if (_refreshPending) {
        _refreshPending = false;
        unawaited(_refreshSnapshot());
      }
    }
  }

  void _applySnapshot(Map<String, dynamic> snapshot) {
    final mode = snapshot['mode']?.toString() ?? 'lobby';
    if (_mode == 'finished' && mode != 'finished') return;
    final leaderboard = snapshot['leaderboard'];
    if (leaderboard is List) _leaderboard = leaderboard;
    final roomSnapshot = _asMap(snapshot['room']);
    final snapshotPlayers = roomSnapshot?['players'];
    if (snapshotPlayers is List) _totalPlayers = snapshotPlayers.length;

    if (mode == 'question') {
      final event = _asMap(snapshot['question_event']);
      if (event != null) {
        final incomingRound = _int(event['current_round_number']);
        // An in-flight snapshot can arrive after the server has already published this round's result.
        if (!(_mode == 'results' && incomingRound <= _roundNumber) && incomingRound >= _roundNumber) {
          final incomingQuestionId = _asMap(event['question'])?['id']?.toString();
          final currentQuestionId = _asMap(_questionEvent?['question'])?['id']?.toString();
          final preserveLocalAnswer = _hasAnswered && incomingRound == _roundNumber &&
              incomingQuestionId == currentQuestionId;
          _setQuestionEvent(event, preserveAnswered: true);
          _hasAnswered = snapshot['has_answered'] == true || preserveLocalAnswer;
          if (snapshot['my_answer_index'] is num) {
            _selectedIndex = (snapshot['my_answer_index'] as num).toInt();
          } else if (!preserveLocalAnswer) {
            if (!_submitting) _selectedIndex = null;
          }
          _answeredCount = _int(snapshot['answered_count']);
        }
      }
    } else if (mode == 'results') {
      final result = _asMap(snapshot['result']);
      if (result != null && _int(result['question_number']) >= _roundNumber) {
        _roundNumber = _int(result['question_number']);
        _result = result;
        _questionEvent = {
          'question_number': result['question_number'],
          'question_count': result['question_count'],
          'question': {'id': result['question_id'], 'text': result['question_text'], 'options': result['options']},
        };
        _mode = 'results';
        _answeredCount = _int(result['answered_count']);
        _totalPlayers = _int(result['total_players']);
        _secondsLeft = 0;
      }
    } else if (mode == 'finished') {
      _mode = 'finished';
      _result = null;
      _pollTimer?.cancel();
      _clockTimer?.cancel();
    } else if (_mode == 'loading') {
      _mode = 'lobby';
    }
    if (mounted) setState(() {});
  }

  void _setQuestionEvent(Map<String, dynamic> event, {bool preserveAnswered = false}) {
    final incomingRound = _int(event['current_round_number'], fallback: _int(event['question_number']));
    final oldQuestionId = _asMap(_questionEvent?['question'])?['id']?.toString();
    final newQuestionId = _asMap(event['question'])?['id']?.toString();
    final isNewQuestion = newQuestionId != oldQuestionId || incomingRound > _roundNumber;
    _questionEvent = event;
    _roundNumber = incomingRound;
    _result = null;
    _mode = 'question';
    _totalPlayers = _int(event['total_players'], fallback: _totalPlayers);
    _answeredCount = _int(event['answered_count'], fallback: _answeredCount);
    if (isNewQuestion) {
      _selectedIndex = null;
      _hasAnswered = false;
      _submitting = false;
      _answeredCount = 0;
    } else if (!preserveAnswered) {
      _selectedIndex = null;
      _hasAnswered = false;
    }
    final end = DateTime.tryParse(event['ends_at']?.toString() ?? '');
    if (end != null) {
      final milliseconds = end.toUtc().difference(DateTime.now().toUtc().add(_serverOffset)).inMilliseconds;
      _secondsLeft = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
    }
  }

  void _updateClock() {
    if (!mounted || _mode != 'question' || _questionEvent == null) return;
    final end = DateTime.tryParse(_questionEvent!['ends_at']?.toString() ?? '');
    if (end == null) return;
    final seconds = end.toUtc().difference(DateTime.now().toUtc().add(_serverOffset)).inMilliseconds;
    final next = seconds <= 0 ? 0 : (seconds / 1000).ceil();
    if (next != _secondsLeft) {
      final previous = _secondsLeft;
      setState(() => _secondsLeft = next);
      _playCountdownSound(previous, next);
    }
  }

  /// Gần hết giờ: bíp mỗi giây (5-4 giây), bíp đôi dồn dập (3-1 giây), báo hết giờ ở 0.
  void _playCountdownSound(int previous, int next) {
    if (!_soundOn) return;
    if (next > 0 && next <= 5) {
      unawaited(SoundService.instance.playTick(urgent: next <= 3));
    } else if (next == 0 && previous > 0) {
      unawaited(SoundService.instance.playTimeUp());
    }
  }

  void _toggleSound() {
    setState(() => _soundOn = !_soundOn);
    SoundService.instance.enabled = _soundOn;
  }

  Future<void> _answer(int index) async {
    if (_hasAnswered || _submitting || _secondsLeft <= 0 || _questionEvent == null || _roomId == null) return;
    final question = _asMap(_questionEvent!['question']);
    final questionId = int.tryParse(question?['id']?.toString() ?? '');
    if (questionId == null) return;
    final round = _roundNumber;
    setState(() {
      _submitting = true;
      _error = null;
      _selectedIndex = index;
    });
    try {
      await _api.room('answer', {
        'room_id': _roomId,
        'question_id': questionId,
        'selected_answer_index': index,
      });
      if (!mounted || round != _roundNumber || _mode != 'question') return;
      setState(() {
        _hasAnswered = true;
        _submitting = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || round != _roundNumber || _mode != 'question') return;
      setState(() {
        _submitting = false;
        _selectedIndex = null;
        _error = error.toString();
      });
      unawaited(_refreshSnapshot());
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry(key.toString(), value));
    return null;
  }

  int _int(dynamic value, {int fallback = 0}) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? fallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_initializing && _mode == 'loading') {
      return Scaffold(appBar: AppBar(title: Text('Phòng ${widget.roomCode}')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_mode == 'lobby') {
      return Scaffold(
        appBar: AppBar(title: Text('Phòng ${widget.roomCode}')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(), const SizedBox(height: 16),
            const Text('Đang chờ trận bắt đầu...'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => context.go(AppRoutes.roomLobbyPath(widget.roomCode)), child: const Text('Về phòng chờ')),
          ]),
        )),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Ôn tập • ${widget.roomCode}'),
        actions: [
          IconButton(
            tooltip: _soundOn ? 'Tắt âm thanh' : 'Bật âm thanh',
            onPressed: _toggleSound,
            icon: Icon(_soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          ),
          IconButton(tooltip: 'Thoát màn hình', onPressed: () => context.go(AppRoutes.rooms), icon: const Icon(Icons.close)),
        ],
      ),
      body: SafeArea(
        child: _mode == 'finished'
            ? _buildFinished(theme)
            : _mode == 'results'
                ? _buildResults(theme)
                : _buildQuestion(theme),
      ),
    );
  }

  Widget _buildQuestion(ThemeData theme) {
    final question = _asMap(_questionEvent?['question']);
    final options = question?['options'] is List ? question!['options'] as List : const [];
    final number = _int(_questionEvent?['question_number'], fallback: _roundNumber == 0 ? 1 : _roundNumber);
    final count = _int(_questionEvent?['question_count'], fallback: 1);
    final duration = _int(_questionEvent?['question_duration_seconds'], fallback: 25);
    final progress = duration <= 0 ? 0.0 : (_secondsLeft / duration).clamp(0.0, 1.0).toDouble();

    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        Expanded(child: Text('Câu $number/$count', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: _secondsLeft <= 5 ? AppColors.error.withOpacity(.12) : AppColors.primary.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
          child: Text('$_secondsLeft giây', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _secondsLeft <= 5 ? AppColors.error : AppColors.primary)),
        ),
      ]),
      const SizedBox(height: 12),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 8)),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(question?['text']?.toString() ?? 'Đang tải câu hỏi...', style: theme.textTheme.titleLarge?.copyWith(height: 1.35)),
        ),
      ),
      const SizedBox(height: 12),
      ...options.map((raw) {
        final option = _asMap(raw) ?? <String, dynamic>{};
        final index = _int(option['index']);
        final chosen = _selectedIndex == index;
        final enabled = !_hasAnswered && !_submitting && _secondsLeft > 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: enabled ? () => _answer(index) : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
                alignment: Alignment.centerLeft,
                side: BorderSide(color: chosen ? AppColors.primary : theme.dividerColor, width: chosen ? 2 : 1),
                backgroundColor: chosen ? AppColors.primary.withOpacity(.09) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(children: [
                CircleAvatar(radius: 15, backgroundColor: chosen ? AppColors.primary : theme.colorScheme.surfaceContainerHighest,
                  child: Text(String.fromCharCode(65 + index), style: TextStyle(color: chosen ? Colors.white : theme.colorScheme.onSurface, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(child: Text(option['text']?.toString() ?? '', style: theme.textTheme.bodyLarge)),
                if (chosen && _submitting) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                if (chosen && _hasAnswered) const Icon(Icons.check_circle, color: AppColors.primary),
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 10),
      Card(color: theme.colorScheme.surfaceContainerHighest, child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.groups_outlined, color: AppColors.primary), const SizedBox(width: 10),
          Expanded(child: Text('Đã trả lời: $_answeredCount/$_totalPlayers người')), 
        ]),
      )),
      if (_hasAnswered) ...[
        const SizedBox(height: 8),
        const Text('Đã ghi nhận đáp án. Điểm và bảng xếp hạng sẽ chỉ công bố khi hết giờ.', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: const TextStyle(color: AppColors.error)),
        TextButton(onPressed: _refreshSnapshot, child: const Text('Đồng bộ lại trạng thái')),
      ],
    ]);
  }

  Widget _buildResults(ThemeData theme) {
    final result = _result ?? <String, dynamic>{};
    final correctIndex = _int(result['correct_answer_index'], fallback: -1);
    final options = result['options'] is List ? result['options'] as List : const [];
    final roundScores = result['round_scores'] is List ? result['round_scores'] as List : const [];
    final currentUserId = context.watch<ProfileProvider>().user.id;
    Map<String, dynamic>? myScore;
    for (final raw in roundScores) {
      final row = _asMap(raw);
      if (row != null && row['user_id']?.toString() == currentUserId) myScore = row;
    }
    String? correctTextValue = result['correct_answer_text']?.toString();
    if (correctTextValue == null && correctIndex >= 0 && correctIndex < options.length) {
      final correctOption = _asMap(options[correctIndex]);
      correctTextValue = correctOption == null ? null : correctOption['text']?.toString();
    }
    final correctText = correctTextValue;
    final questionNumber = _int(result['question_number'], fallback: _roundNumber);
    final count = _int(result['question_count'], fallback: 1);

    return ListView(padding: const EdgeInsets.all(20), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(.10), borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          const Icon(Icons.emoji_events_outlined, size: 44, color: AppColors.warning),
          const SizedBox(height: 8),
          Text('Kết quả câu $questionNumber/$count', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(result['question_text']?.toString() ?? '', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('Đáp án đúng: ${correctIndex >= 0 ? String.fromCharCode(65 + correctIndex) : ''}. ${correctText ?? ''}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          if (myScore != null) ...[
            const SizedBox(height: 10),
            Text(myScore['is_correct'] == true ? '+${_int(myScore['points_earned'])} điểm' : '0 điểm câu này', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: myScore['is_correct'] == true ? AppColors.success : AppColors.error)),
            Text(myScore['answered'] == true ? 'Thời gian phản hồi: ${((_int(myScore['elapsed_milliseconds']) / 1000)).toStringAsFixed(2)} giây' : 'Bạn chưa trả lời câu này', style: theme.textTheme.bodySmall),
          ],
        ]),
      ),
      if ((result['explanation']?.toString() ?? '').trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Text('Giải thích: ${result['explanation']}'))),
      ],
      const SizedBox(height: 18),
      Text('Điểm của câu này', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      ...roundScores.map((raw) {
        final row = _asMap(raw) ?? <String, dynamic>{};
        final points = _int(row['points_earned']);
        return Card(child: ListTile(
          leading: CircleAvatar(child: Text(row['avatar_emoji']?.toString() ?? '👤')),
          title: Text(row['name']?.toString() ?? 'Người chơi'),
          subtitle: Text(row['answered'] == true ? (row['is_correct'] == true ? 'Trả lời đúng' : 'Trả lời sai') : 'Hết giờ, chưa trả lời'),
          trailing: Text('+$points', style: TextStyle(fontWeight: FontWeight.w800, color: points > 0 ? AppColors.success : theme.textTheme.bodyMedium?.color)),
        ));
      }),
      const SizedBox(height: 14),
      Text('Bảng xếp hạng tổng', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      ..._leaderboard.map((raw) => _leaderboardTile(raw, theme)),
      const SizedBox(height: 12),
      const Center(child: Text('Câu tiếp theo sẽ tự xuất hiện sau 5 giây…', style: TextStyle(color: AppColors.textSecondary))),
      const SizedBox(height: 30),
    ]);
  }

  Widget _buildFinished(ThemeData theme) {
    final currentUserId = context.watch<ProfileProvider>().user.id;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 16),
      const Icon(Icons.emoji_events, color: AppColors.warning, size: 76),
      const SizedBox(height: 10),
      Text('Trận ôn tập kết thúc!', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('Bảng xếp hạng cuối cùng', textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ..._leaderboard.map((raw) {
        final row = _asMap(raw) ?? <String, dynamic>{};
        final mine = row['user_id']?.toString() == currentUserId;
        return Card(color: mine ? AppColors.primary.withOpacity(.10) : null, child: _leaderboardTile(row, theme, emphasize: mine));
      }),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () async {
          await context.read<RoomProvider>().leaveRoom();
          if (mounted) context.go(AppRoutes.rooms);
        },
        icon: const Icon(Icons.home_outlined), label: const Text('Về phòng thi'),
      ),
    ]);
  }

  Widget _leaderboardTile(dynamic raw, ThemeData theme, {bool emphasize = false}) {
    final row = _asMap(raw) ?? <String, dynamic>{};
    final rank = _int(row['rank'], fallback: 0);
    final score = _int(row['score']);
    final correct = _int(row['correct_answers']);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: rank == 1 ? AppColors.warning.withOpacity(.2) : theme.colorScheme.surfaceContainerHighest,
          child: Text(rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank'),
        ),
        title: Text(row['name']?.toString() ?? 'Người chơi', style: TextStyle(fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600)),
        subtitle: Text('$correct câu đúng'),
        trailing: Text('$score điểm', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
