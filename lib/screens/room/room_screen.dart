// lib/screens/room/room_screen.dart
// Màn hình Phòng thi — Hub cho tính năng thi đấu.
// Hiển thị: Tạo phòng / Tham gia phòng + danh sách phòng đang hoạt động.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../data/mock_rooms.dart';
import '../../models/room.dart';
import '../../providers/room_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/primary_button.dart';

class RoomScreen extends StatelessWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
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

              // Danh sách mock rooms
              ...mockRooms.asMap().entries.map((entry) {
                final index = entry.key;
                final room = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RoomCard(room: room).animate().fadeIn(
                        delay: Duration(milliseconds: 350 + index * 100),
                        duration: 350.ms,
                      ),
                );
              }),

              const Gap(kSpaceXL),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Sheet: Tạo phòng ──
  void _showCreateRoomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CreateRoomSheet(),
    );
  }

  // ── Bottom Sheet: Tham gia phòng ──
  void _showJoinRoomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _JoinRoomSheet(),
    );
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

          Text('Tạo phòng thi', style: theme.textTheme.headlineSmall),
          const Gap(kSpaceXL),

          // Chọn bài (đơn giản: hiện tên bài đầu tiên)
          Text('Bài thi', style: theme.textTheme.labelLarge),
          const Gap(6),
          Container(
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
                const Text('Flutter Cơ Bản'),
                const Spacer(),
                Icon(Icons.expand_more,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),

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

          const Gap(kSpaceXL),

          PrimaryButton(
            text: 'Tạo phòng',
            isLoading: isLoading,
            icon: Icons.add_circle_outline,
            onPressed: () async {
              final room = await context.read<RoomProvider>().createRoom(
                    quiz: mockRooms[0].quiz,
                    maxPlayers: _maxPlayers,
                    durationMinutes: _duration,
                  );
              if (room != null && context.mounted) {
                Navigator.pop(context);
                _showRoomCreated(context, room.code);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRoomCreated(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Phòng đã tạo! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mã phòng:'),
            const Gap(8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
            ),
            const Gap(8),
            const Text('Chia sẻ mã này với bạn bè',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
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
                    if (room != null && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Đã vào phòng ${room.code} — ${room.quiz.title}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
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
