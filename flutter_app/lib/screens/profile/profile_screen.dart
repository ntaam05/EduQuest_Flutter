// lib/screens/profile/profile_screen.dart
// Màn hình Hồ sơ người dùng.
// Hiển thị: Avatar, thống kê, achievements, settings toggle.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../routes/app_router.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/stat_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final user = profileProvider.user;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(kSpaceLG),

              // ── Header chỉnh sửa ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Hồ sơ', style: theme.textTheme.headlineLarge)
                      .animate()
                      .fadeIn(duration: 300.ms),
                  IconButton(
                    onPressed: () => _showEditProfileDialog(context, profileProvider),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Chỉnh sửa hồ sơ',
                  ),
                ],
              ),

              const Gap(kSpaceLG),

              // ── Profile Card ──
              _ProfileCard(user: user)
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 400.ms),

              const Gap(kSpaceLG),

              // ── Statistics Grid ──
              const SectionHeader(title: 'Thống kê'),
              const Gap(kSpaceMD),
              const _StatsGrid(),

              const Gap(kSpaceLG),

              // ── Achievements ──
              const SectionHeader(title: 'Thành tích'),
              const Gap(kSpaceMD),
              const _AchievementsSection(),

              const Gap(kSpaceLG),

              // ── Settings ──
              const SectionHeader(title: 'Cài đặt'),
              const Gap(kSpaceMD),
              _SettingsSection(provider: profileProvider),

              const Gap(kSpaceXL),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context, ProfileProvider provider) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditProfileDialog(provider: provider),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.provider});

  final ProfileProvider provider;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emojiController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.provider.user.name);
    _emojiController = TextEditingController(text: widget.provider.user.avatarEmoji ?? '👤');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmedName = _nameController.text.trim();
    final trimmedEmoji = _emojiController.text.trim();
    if (trimmedName.isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.provider.updateProfile(
        name: trimmedName,
        avatarEmoji: trimmedEmoji.isEmpty ? '👤' : trimmedEmoji,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final emojiPreview = _emojiController.text.trim();

    return AlertDialog(
      title: const Text('Chỉnh sửa hồ sơ'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Tên hiển thị'),
              ),
              const Gap(kSpaceMD),
              TextField(
                controller: _emojiController,
                maxLength: 16,
                decoration: const InputDecoration(labelText: 'Avatar (emoji)'),
              ),
              const Gap(kSpaceSM),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    emojiPreview.isEmpty ? '👤' : emojiPreview,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// Profile Card — Avatar + Tên + Role + XP
// ──────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final dynamic user;

  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                user.avatarEmoji ?? '👤',
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
          const Gap(kSpaceMD),
          // Tên + Role + XP
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Gap(8),
                // XP bar
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AppColors.accentLight, size: 16),
                    const Gap(4),
                    Text(
                      '${user.xp} XP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Circular Progress (điểm TB)
          CircularPercentIndicator(
            radius: 34,
            lineWidth: 5,
            percent: user.averageScore / 100,
            center: Text(
              '${user.averageScore.toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            progressColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.2),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 800,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Grid thống kê 2x2
// ──────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ProfileProvider>().user;

    final stats = [
      _StatItem(
        label: 'Bài đã làm',
        value: '${user.totalQuizzes}',
        icon: Icons.assignment_turned_in_outlined,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryContainer,
      ),
      _StatItem(
        label: 'Câu hỏi',
        value: '${user.totalQuestions}',
        icon: Icons.help_outline_rounded,
        iconColor: AppColors.secondary,
        iconBgColor: AppColors.secondaryContainer,
      ),
      _StatItem(
        label: 'Điểm TB',
        value: '${user.averageScore.toInt()}%',
        icon: Icons.star_outline_rounded,
        iconColor: AppColors.accent,
        iconBgColor: const Color(0xFFFFF8E1),
      ),
      _StatItem(
        label: '🔥 Streak',
        value: '${user.streakDays} ngày',
        icon: Icons.local_fire_department_outlined,
        iconColor: AppColors.warning,
        iconBgColor: AppColors.warningContainer,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final s = stats[index];
        return StatCard(
          label: s.label,
          value: s.value,
          icon: s.icon,
          iconColor: s.iconColor,
          iconBgColor: s.iconBgColor,
        )
            .animate()
            .fadeIn(delay: Duration(milliseconds: 200 + index * 80))
            .slideY(
                begin: 0.1,
                end: 0,
                delay: Duration(milliseconds: 200 + index * 80));
      },
    );
  }
}

class _StatItem {
  final String label, value;
  final IconData icon;
  final Color iconColor, iconBgColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });
}

// ──────────────────────────────────────────
// Achievements Section
// ──────────────────────────────────────────
class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context) {
    final achievements = [
      _Achievement(emoji: '🏆', title: 'Quiz Master', desc: 'Hoàn thành 20+ bài'),
      _Achievement(emoji: '🔥', title: '7 Day Streak', desc: 'Học 7 ngày liên tiếp'),
      _Achievement(emoji: '📚', title: 'Bookworm', desc: 'Trả lời 300+ câu hỏi'),
    ];

    return Column(
      children: achievements.asMap().entries.map((entry) {
        final index = entry.key;
        final a = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AchievementCard(achievement: a)
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: 300 + index * 100),
                duration: 350.ms,
              )
              .slideX(
                begin: 0.05,
                end: 0,
                delay: Duration(milliseconds: 300 + index * 100),
                duration: 350.ms,
              ),
        );
      }).toList(),
    );
  }
}

class _Achievement {
  final String emoji, title, desc;
  const _Achievement({required this.emoji, required this.title, required this.desc});
}

class _AchievementCard extends StatelessWidget {
  final _Achievement achievement;

  const _AchievementCard({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          // Badge nền gradient
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.amberGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(achievement.emoji,
                  style: const TextStyle(fontSize: 24)),
            ),
          ),
          const Gap(kSpaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(achievement.title, style: theme.textTheme.titleMedium),
                const Gap(2),
                Text(achievement.desc, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          // Checkmark đã đạt
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.successContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: AppColors.success, size: 16),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Settings Section
// ──────────────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final ProfileProvider provider;

  const _SettingsSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          // Dark Mode toggle
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            iconColor: const Color(0xFF5C6BC0),
            iconBgColor: const Color(0xFFE8EAF6),
            title: 'Dark Mode',
            trailing: Switch(
              value: provider.isDarkMode,
              onChanged: (_) => provider.toggleDarkMode(),
              activeThumbColor: AppColors.primary,
            ),
          ),
          _Divider(),

          // Notifications toggle
          _SettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: AppColors.warning,
            iconBgColor: AppColors.warningContainer,
            title: 'Thông báo',
            trailing: Switch(
              value: provider.notificationsEnabled,
              onChanged: (_) => provider.toggleNotifications(),
              activeThumbColor: AppColors.primary,
            ),
          ),
          _Divider(),

          // Language
          _SettingsTile(
            icon: Icons.language_outlined,
            iconColor: AppColors.success,
            iconBgColor: AppColors.successContainer,
            title: 'Ngôn ngữ',
            trailing: Text(
              provider.language == 'vi' ? '🇻🇳 Tiếng Việt' : '🇺🇸 English',
              style: theme.textTheme.bodySmall,
            ),
            onTap: () {
              // Cài đặt ngôn ngữ được lưu trên backend.
              provider.setLanguage(provider.language == 'vi' ? 'en' : 'vi');
            },
          ),
          _Divider(),

          // Lịch sử làm bài (GET /api/quizzes/attempts/mine)
          _SettingsTile(
            icon: Icons.history_rounded,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primaryContainer,
            title: 'Lịch sử làm bài',
            onTap: () => context.push(AppRoutes.history),
          ),
          _Divider(),

          // About
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primaryContainer,
            title: 'Về ứng dụng',
            trailing: Text(
              'v$kAppVersion',
              style: theme.textTheme.bodySmall,
            ),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: kAppName,
                applicationVersion: kAppVersion,
                applicationLegalese: '© 2026 QuizUp. Đồ án Lập trình di động.',
              );
            },
          ),
          _Divider(),

          // Đổi mật khẩu (POST /api/auth/change-password)
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primaryContainer,
            title: 'Đổi mật khẩu',
            onTap: () => _showChangePasswordDialog(context),
          ),
          _Divider(),

          // Logout
          _SettingsTile(
            icon: Icons.logout_rounded,
            iconColor: AppColors.error,
            iconBgColor: AppColors.errorContainer,
            title: 'Đăng xuất',
            titleColor: AppColors.error,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đăng xuất?'),
                  content: const Text('Bạn sẽ cần đăng nhập lại để tiếp tục sử dụng.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
                    ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Đăng xuất')),
                  ],
                ),
              );
              if (confirmed == true) {
                // Xóa token; router tự chuyển về màn Đăng nhập và Provider được dựng lại.
                await ApiClient.instance.logout();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 60, endIndent: 16);
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    this.titleColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: titleColor,
        ),
      ),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right,
                  color: AppColors.textSecondary, size: 18)
              : null),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

/// Hộp thoại đổi mật khẩu — gọi POST /api/auth/change-password.
Future<void> _showChangePasswordDialog(BuildContext context) async {
  final current = TextEditingController();
  final next = TextEditingController();
  String? error;
  var busy = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Đổi mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu mới (tối thiểu 8 ký tự)'),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: const TextStyle(color: AppColors.error)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: busy
                ? null
                : () async {
                    if (current.text.isEmpty) {
                      setState(() => error = 'Vui lòng nhập mật khẩu hiện tại.');
                      return;
                    }
                    if (next.text.length < 8) {
                      setState(() => error = 'Mật khẩu mới tối thiểu 8 ký tự.');
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await ApiClient.instance.post('/api/auth/change-password', {
                        'current_password': current.text,
                        'new_password': next.text,
                      });
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã đổi mật khẩu.')),
                        );
                      }
                    } catch (e) {
                      setState(() {
                        busy = false;
                        error = e.toString();
                      });
                    }
                  },
            child: const Text('Lưu'),
          ),
        ],
      ),
    ),
  );
}
