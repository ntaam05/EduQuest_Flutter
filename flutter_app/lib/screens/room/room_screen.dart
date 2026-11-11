// lib/screens/room/room_screen.dart
// Màn hình Phòng thi — Hub cho tính năng thi đấu.
// Hiển thị: Tạo phòng / Tham gia phòng + danh sách phòng đang hoạt động.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../models/room.dart';
import '../../providers/room_provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_provider.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/primary_button.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RoomProvider>().loadRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomProvider = context.watch<RoomProvider>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<RoomProvider>().loadRooms(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(kSpaceLG),

              // ── Header ──
              Text('Phòng thi', style: theme.textTheme.headlineLarge)
                  .animate()
                  .fadeIn(duration: 300.ms),
              const Gap(4),
              Text('Thi đấu với bạn bè', style: theme.textTheme.bodyMedium)
                  .animate()
                  .fadeIn(delay: 100.ms),

              const Gap(kSpaceXL),

              // ── Hai nút chính ──
              Row(
                children: [
                  // Tạo phòng
                  Expanded(
                    child: _ActionCard(
                      emoji: '🏆',
                      title: 'Tạo phòng',
                      subtitle: 'Tổ chức thi đấu',
                      gradient: AppColors.primaryGradient,
                      onTap: () => _showCreateRoomSheet(context),
                    ).animate().fadeIn(delay: 150.ms).slideX(
                          begin: -0.1,
                          end: 0,
                          delay: 150.ms,
                          duration: 400.ms,
                        ),
                  ),
                  const Gap(12),
                  // Tham gia phòng
                  Expanded(
                    child: _ActionCard(
                      emoji: '🔑',
                      title: 'Vào phòng',
                      subtitle: 'Nhập mã phòng',
                      gradient: AppColors.amberGradient,
                      onTap: () => _showJoinRoomSheet(context),
                    ).animate().fadeIn(delay: 250.ms).slideX(
                          begin: 0.1,
                          end: 0,
                          delay: 250.ms,
                          duration: 400.ms,
                        ),
                  ),
                ],
              ),

              const Gap(kSpaceXL),

              // ── Phòng đang hoạt động ──
              Text('Phòng đang hoạt động',
                      style: theme.textTheme.headlineSmall)
                  .animate()
                  .fadeIn(delay: 300.ms),
              const Gap(kSpaceMD),

              // Danh sách phòng được tải từ backend
              if (roomProvider.rooms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      roomProvider.errorMessage == null
                          ? 'Chưa có phòng thi đang hoạt động.'
                          : 'Không tải được danh sách phòng: ${roomProvider.errorMessage}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ...roomProvider.rooms.asMap().entries.map((entry) {
                  final index = entry.key;
                  final room = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openRoom(room),
                      child: _RoomCard(room: room).animate().fadeIn(
                            delay: Duration(milliseconds: 100 + index * 60),
                            duration: 350.ms,
                          ),
                    ),
                  );
                }),

              const Gap(kSpaceXL),
            ],
          ),
          ),
        ),
      ),
    );
  }


  Future<void> _openRoom(Room room) async {
    final messenger = ScaffoldMessenger.of(context);
    final currentUserId = context.read<ProfileProvider>().user.id;
    final isMember = room.players.any((player) => player.id == currentUserId);
    if (room.status == RoomStatus.waiting && !isMember) {
      final joined = await context.read<RoomProvider>().joinRoom(room.code);
      if (!mounted) return;
      if (joined == null) {
        messenger.showSnackBar(SnackBar(content: Text(context.read<RoomProvider>().errorMessage ?? 'Không thể vào phòng.')));
        return;
      }
    } else if (!isMember) {
      messenger.showSnackBar(const SnackBar(content: Text('Trận đã bắt đầu; chỉ thành viên đã vào phòng mới có thể quay lại.')));
      return;
    }
    if (mounted) context.go(AppRoutes.roomLobbyPath(room.code));
  }

  // ── Bottom Sheet: Tạo phòng ──
  Future<void> _showCreateRoomSheet(BuildContext context) async {
    final room = await showModalBottomSheet<Room>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CreateRoomSheet(),
    );
    if (room != null && context.mounted) context.go(AppRoutes.roomLobbyPath(room.code));
  }

  // ── Bottom Sheet: Tham gia phòng ──
  Future<void> _showJoinRoomSheet(BuildContext context) async {
    final room = await showModalBottomSheet<Room>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _JoinRoomSheet(),
    );
    if (room != null && context.mounted) context.go(AppRoutes.roomLobbyPath(room.code));
  }
}

// ──────────────────────────────────────────
// Card hành động (Tạo phòng / Vào phòng)
// ──────────────────────────────────────────
class _ActionCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 32)),
              const Gap(12),
              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(2),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Card phòng trong danh sách
// ──────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final Room room;

  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    switch (room.status) {
      case RoomStatus.waiting:
        statusColor = AppColors.success;
        break;
      case RoomStatus.playing:
        statusColor = AppColors.warning;
        break;
      case RoomStatus.showingResults:
        statusColor = AppColors.warning;
        break;
      case RoomStatus.finished:
        statusColor = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          // Room code badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              room.code,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                fontSize: 15,
                letterSpacing: 1,
              ),
            ),
          ),
          const Gap(12),
          // Thông tin phòng
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.quiz.title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 13, color: theme.textTheme.bodySmall?.color),
                    const Gap(3),
                    Text(
                      '${room.currentPlayers}/${room.maxPlayers} người',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Gap(12),
                    // Status dot
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      room.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Chủ phòng
          Text(
            room.host.avatarEmoji ?? '👤',
            style: const TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Bottom Sheet: Tạo phòng
// ──────────────────────────────────────────
class _CreateRoomSheet extends StatefulWidget {
  const _CreateRoomSheet();

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  int _maxPlayers = 10;
  int _duration = 15;
  int _questionDuration = 25;
  String? _quizId; // Bài người dùng chọn; null = chưa chọn (dùng bài đầu danh sách)

  @override
  void initState() {
    super.initState();
    // Làm mới danh sách để thấy cả những bài vừa upload/tạo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<QuizProvider>().loadQuizzes();
    });
  }

  Quiz? _selectedQuiz(List<Quiz> quizzes) {
    if (quizzes.isEmpty) return null;
    for (final quiz in quizzes) {
      if (quiz.id == _quizId) return quiz;
    }
    return quizzes.first;
  }

  Future<void> _pickQuiz(List<Quiz> quizzes) async {
    final current = _selectedQuiz(quizzes);
    final picked = await showModalBottomSheet<Quiz>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Chọn bài ôn tập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: quizzes.length,
                  itemBuilder: (ctx, index) {
                    final quiz = quizzes[index];
                    final selected = quiz.id == current?.id;
                    return ListTile(
                      leading: Text(quiz.iconEmoji ?? '📚', style: const TextStyle(fontSize: 22)),
                      title: Text(quiz.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${quiz.subject} • ${quiz.questionCount} câu • ${quiz.durationMinutes} phút'),
                      trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                      onTap: () => Navigator.of(ctx).pop(quiz),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _quizId = picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final roomProvider = context.watch<RoomProvider>();
    final quizProvider = context.watch<QuizProvider>();
    final availableQuizzes = quizProvider.quizzes;
    final selectedQuiz = _selectedQuiz(availableQuizzes);
    final isLoading = roomProvider.status == RoomActionStatus.loading;

    return Container(
      padding: EdgeInsets.only(
        left: kScreenPadding,
        right: kScreenPadding,
        top: kSpaceLG,
        bottom: MediaQuery.of(context).viewInsets.bottom + kSpaceLG,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(kSpaceLG),

          Text('Tạo phòng thi', style: theme.textTheme.headlineSmall),
          const Gap(kSpaceXL),

          // Chọn bài: chạm để mở danh sách và chọn bất kỳ bài nào
          Text('Bài thi', style: theme.textTheme.labelLarge),
          const Gap(6),
          InkWell(
            onTap: availableQuizzes.isEmpty ? null : () => _pickQuiz(availableQuizzes),
            borderRadius: BorderRadius.circular(12),
            child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark2 : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                const Text('📱', style: TextStyle(fontSize: 20)),
                const Gap(10),
                Expanded(
                  child: Text(
                    selectedQuiz == null ? 'Chưa có bài thi khả dụng' : selectedQuiz.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.expand_more,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          )),
          if (availableQuizzes.isNotEmpty) ...[
            const Gap(4),
            Text('Chạm để chọn bài khác • ${availableQuizzes.length} bài có sẵn', style: theme.textTheme.bodySmall),
          ],

          const Gap(kSpaceMD),

          // Số người + Thời gian
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Số người', style: theme.textTheme.labelLarge),
                    const Gap(6),
                    _NumberStepper(
                      value: _maxPlayers,
                      min: 2,
                      max: 20,
                      onChanged: (v) => setState(() => _maxPlayers = v),
                    ),
                  ],
                ),
              ),
              const Gap(kSpaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thời gian (phút)', style: theme.textTheme.labelLarge),
                    const Gap(6),
                    _NumberStepper(
                      value: _duration,
                      min: 5,
                      max: 60,
                      step: 5,
                      onChanged: (v) => setState(() => _duration = v),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Gap(kSpaceMD),
          Text('Thời gian cho mỗi câu (giây)', style: theme.textTheme.labelLarge),
          const Gap(6),
          _NumberStepper(
            value: _questionDuration,
            min: 20,
            max: 30,
            step: 5,
            onChanged: (v) => setState(() => _questionDuration = v),
          ),
          const Gap(4),
          Text('Mỗi câu giữ nguyên trong ${_questionDuration} giây. Hết giờ, server công bố điểm và bảng xếp hạng; sau 5 giây sẽ tự chuyển câu.', style: theme.textTheme.bodySmall),

          if (availableQuizzes.isEmpty) ...[
            const Gap(8),
            Text(
              'Máy chủ chưa có bài thi chứa câu hỏi. Hãy thêm bài thi trước khi tạo phòng.',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
          if (roomProvider.status == RoomActionStatus.error && roomProvider.errorMessage != null) ...[
            const Gap(8),
            Text(roomProvider.errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],

          const Gap(kSpaceXL),

          PrimaryButton(
            text: 'Tạo phòng',
            isLoading: isLoading,
            icon: Icons.add_circle_outline,
            onPressed: availableQuizzes.isEmpty || isLoading ? null : () async {
              final room = await context.read<RoomProvider>().createRoom(
                    quiz: selectedQuiz!,
                    maxPlayers: _maxPlayers,
                    durationMinutes: _duration,
                    questionDurationSeconds: _questionDuration,
                  );
              if (room != null && context.mounted) Navigator.pop(context, room);
            },
          ),
        ],
      ),
    );
  }

}

// ──────────────────────────────────────────
// Bottom Sheet: Tham gia phòng
// ──────────────────────────────────────────
class _JoinRoomSheet extends StatefulWidget {
  const _JoinRoomSheet();

  @override
  State<_JoinRoomSheet> createState() => _JoinRoomSheetState();
}

class _JoinRoomSheetState extends State<_JoinRoomSheet> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
  }

  void _onCodeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final roomProvider = context.watch<RoomProvider>();
    final isLoading = roomProvider.status == RoomActionStatus.loading;

    return Container(
      padding: EdgeInsets.only(
        left: kScreenPadding,
        right: kScreenPadding,
        top: kSpaceLG,
        bottom: MediaQuery.of(context).viewInsets.bottom + kSpaceLG,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(kSpaceLG),

          Text('Tham gia phòng', style: theme.textTheme.headlineSmall),
          const Gap(4),
          Text('Nhập mã phòng 6 ký tự', style: theme.textTheme.bodyMedium),
          const Gap(kSpaceLG),

          // Input mã phòng
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
            ),
            decoration: const InputDecoration(
              hintText: 'ABCD12',
              counterText: '',
            ),
          ),

          // Lỗi (nếu có)
          if (roomProvider.status == RoomActionStatus.error &&
              roomProvider.errorMessage != null) ...[
            const Gap(8),
            Text(
              roomProvider.errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],

          const Gap(kSpaceLG),

          PrimaryButton(
            text: 'Tham gia',
            isLoading: isLoading,
            icon: Icons.login_rounded,
            onPressed: _codeController.text.length == 6
                ? () async {
                    final room = await context
                        .read<RoomProvider>()
                        .joinRoom(_codeController.text);
                    if (room != null && context.mounted) Navigator.pop(context, room);
                  }
                : null,
          ),

          const Gap(8),
          // Gợi ý mã phòng test
          Center(
            child: Text(
              'Thử mã: ABCD12',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Number Stepper (+/-) cho form tạo phòng
// ──────────────────────────────────────────
class _NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          // Nút -
          IconButton(
            onPressed:
                value > min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove, size: 18),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          // Giá trị
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          // Nút +
          IconButton(
            onPressed:
                value < max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add, size: 18),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
