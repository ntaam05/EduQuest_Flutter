// lib/screens/home/home_screen.dart
// Màn hình Trang chủ — Dashboard chính của app.
// Hiển thị: Header, Statistics, Learning Progress, Recent Quizzes, Recommended.
// Animation: stagger cards xuất hiện lần lượt khi vào màn hình.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/profile_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/common/stat_card.dart';
import '../../widgets/quiz/quiz_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          // Pull-to-refresh (mock — không làm gì)
          onRefresh: () async => await Future.delayed(const Duration(seconds: 1)),
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(kSpaceLG),

                // ── Header ──────────────────────
                const _HomeHeader()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0, duration: 400.ms),

                const Gap(kSpaceLG),

                // ── Statistics Grid ──────────────
                const _StatisticsGrid(),

                const Gap(kSpaceLG),

                // ── Learning Progress ────────────
                const _LearningProgress()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),

                const Gap(kSpaceLG),

                // ── Recent Quizzes ───────────────
                const _RecentQuizzes(),

                const Gap(kSpaceLG),

                // ── Recommended ─────────────────
                const _RecommendedSection(),

                const Gap(kSpaceXL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Header: Avatar + Tên + Notification
// ──────────────────────────────────────────
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Lấy thông tin user từ ProfileProvider
    final user = context.watch<ProfileProvider>().user;

    return Row(
      children: [
        // Greeting + Tên
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào 👋',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              ),
              const Gap(2),
              Text(
                user.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Notification icon
        IconButton(
          onPressed: () {
            // TODO Phase 2: Mở notification panel
          },
          icon: Badge(
            // Badge đỏ nhỏ báo có thông báo mới
            backgroundColor: AppColors.error,
            smallSize: 8,
            child: const Icon(Icons.notifications_outlined, size: 24),
          ),
        ),

        const Gap(4),

        // Avatar
        GestureDetector(
          onTap: () {
            // TODO Phase 2: Mở profile
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                user.avatarEmoji ?? '👤',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// Statistics: 4 card với stagger animation
// ──────────────────────────────────────────
class _StatisticsGrid extends StatelessWidget {
  const _StatisticsGrid();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ProfileProvider>().user;

    // Dữ liệu cho 4 card thống kê
    final stats = [
      _StatData(
        label: 'Bài đã làm',
        value: '${user.totalQuizzes}',
        icon: Icons.assignment_turned_in_outlined,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryContainer,
      ),
      _StatData(
        label: 'Câu trả lời',
        value: '${user.totalQuestions}',
        icon: Icons.help_outline_rounded,
        iconColor: AppColors.secondary,
        iconBgColor: AppColors.secondaryContainer,
      ),
      _StatData(
        label: 'Điểm TB',
        value: '${user.averageScore.toInt()}%',
        icon: Icons.star_outline_rounded,
        iconColor: AppColors.accent,
        iconBgColor: const Color(0xFFFFF8E1),
      ),
      _StatData(
        label: '🔥 Streak',
        value: '${user.streakDays} ngày',
        icon: Icons.local_fire_department_outlined,
        iconColor: AppColors.warning,
        iconBgColor: AppColors.warningContainer,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tổng quan'),
        const Gap(kSpaceMD),
        // Grid 2 cột
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3, // Tỉ lệ width/height của mỗi card
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final stat = stats[index];
            // Stagger: mỗi card xuất hiện trễ hơn 100ms
            return StatCard(
              label: stat.label,
              value: stat.value,
              icon: stat.icon,
              iconColor: stat.iconColor,
              iconBgColor: stat.iconBgColor,
            )
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 100 + index * 100),
                  duration: 400.ms,
                )
                .slideY(
                  begin: 0.2,
                  end: 0,
                  delay: Duration(milliseconds: 100 + index * 100),
                  duration: 400.ms,
                );
          },
        ),
      ],
    );
  }
}

// Data class cho stat
class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });
}

// ──────────────────────────────────────────
// Learning Progress section
// ──────────────────────────────────────────
class _LearningProgress extends StatelessWidget {
  const _LearningProgress();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const progress = 0.82; // Mock: 82% mục tiêu tuần

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Gradient nền nhẹ
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A1A3E),
                  const Color(0xFF2D1B69),
                ]
              : [
                  const Color(0xFFEEF2FF),
                  const Color(0xFFF3E5F5),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.primaryContainer,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tiến độ tuần này',
                      style: theme.textTheme.titleLarge,
                    ),
                    const Gap(4),
                    Text(
                      'Bạn đã hoàn thành ${(progress * 100).toInt()}% mục tiêu',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              // Vòng tròn hiển thị %
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(kSpaceMD),
          // Progress bar
          LinearPercentIndicator(
            percent: progress,
            lineHeight: 10,
            backgroundColor: isDark
                ? AppColors.borderDark
                : AppColors.primary.withOpacity(0.15),
            linearGradient: AppColors.primaryGradient,
            barRadius: const Radius.circular(8),
            padding: EdgeInsets.zero,
            animation: true,
            animationDuration: 800,
          ),
          const Gap(kSpaceSM),
          // Nhãn
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: theme.textTheme.bodySmall),
              Text('100%', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Recent Quizzes
// ──────────────────────────────────────────
class _RecentQuizzes extends StatelessWidget {
  const _RecentQuizzes();

  @override
  Widget build(BuildContext context) {
    // Lấy 2 quiz gần nhất từ QuizProvider
    final quizzes = context.watch<QuizProvider>().quizzes.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Bài gần đây',
          actionText: 'Xem tất cả',
          onAction: () {
            // TODO: Navigate to Review screen
          },
        ),
        const Gap(kSpaceMD),
        ...quizzes.asMap().entries.map((entry) {
          final index = entry.key;
          final quiz = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < quizzes.length - 1 ? 12 : 0),
            child: QuizCard(
              quiz: quiz,
              onTap: () {
                context.push(AppRoutes.quizPath(quiz.id));
              },
            )
                .animate()
                .fadeIn(
                  delay: Duration(milliseconds: 200 + index * 150),
                  duration: 400.ms,
                )
                .slideX(
                  begin: 0.1,
                  end: 0,
                  delay: Duration(milliseconds: 200 + index * 150),
                  duration: 400.ms,
                ),
          );
        }),
      ],
    );
  }
}

// ──────────────────────────────────────────
// Recommended Section
// ──────────────────────────────────────────
class _RecommendedSection extends StatelessWidget {
  const _RecommendedSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Các gợi ý học tập (mock)
    final recommendations = [
      _RecommendItem(emoji: '🏗️', title: 'OOP', subtitle: '10 câu • Chưa làm'),
      _RecommendItem(emoji: '🗄️', title: 'CSDL', subtitle: '10 câu • Đang làm'),
      _RecommendItem(emoji: '📱', title: 'Flutter', subtitle: '10 câu • Đã làm'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Có thể bạn quan tâm'),
        const Gap(kSpaceMD),
        // Horizontal scroll list
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            separatorBuilder: (_, __) => const Gap(12),
            itemBuilder: (context, index) {
              final item = recommendations[index];
              return _RecommendCard(
                item: item,
                isDark: isDark,
              )
                  .animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 300 + index * 100),
                    duration: 400.ms,
                  )
                  .slideX(
                    begin: 0.15,
                    end: 0,
                    delay: Duration(milliseconds: 300 + index * 100),
                    duration: 400.ms,
                  );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendItem {
  final String emoji;
  final String title;
  final String subtitle;

  const _RecommendItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

class _RecommendCard extends StatelessWidget {
  final _RecommendItem item;
  final bool isDark;

  const _RecommendCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        // Có thể navigate dựa theo subject/category, tạm thời placeholder
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chức năng xem ${item.title} (Phase 3)')),
        );
      },
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 28)),
            const Gap(8),
            Text(
              item.title,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Gap(2),
            Text(
              item.subtitle,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
