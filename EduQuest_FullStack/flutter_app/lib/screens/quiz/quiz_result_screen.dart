// lib/screens/quiz/quiz_result_screen.dart
// Màn hình kết quả sau khi làm bài.
// Hiển thị: Lottie success animation, Điểm, Thống kê, Action buttons.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/primary_button.dart';

class QuizResultScreen extends StatefulWidget {
  final String quizId;

  const QuizResultScreen({super.key, required this.quizId});

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  @override
  void initState() {
    super.initState();
    // Cập nhật thống kê profile ngay khi mở màn hình kết quả
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final quizProvider = context.read<QuizProvider>();
      final result = quizProvider.lastResult;
      if (result != null) {
        context.read<ProfileProvider>().incrementStats(
              questionsAnswered: result.totalQuestions,
              score: result.scorePercent,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final result = context.watch<QuizProvider>().lastResult;

    if (result == null || result.quiz.id != widget.quizId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Không tìm thấy kết quả bài làm.'),
              const Gap(16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Về trang chủ'),
              ),
            ],
          ),
        ),
      );
    }

    // Nếu trên 50% là pass, đổi màu
    final isPassed = result.scorePercent >= 50.0;
    final highlightColor = isPassed ? AppColors.success : AppColors.warning;
    final highlightGradient = isPassed ? AppColors.successGradient : AppColors.amberGradient;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Gap(kSpaceXL),

              // ── Lottie Animation / Emoji ──
              // Ghi chú: Dùng Emoji lớn thay Lottie tạm thời nếu chưa có file asset
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: highlightColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    isPassed ? '🎉' : '💪',
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

              const Gap(kSpaceLG),

              // ── Tiêu đề ──
              Text(
                isPassed ? 'Tuyệt vời!' : 'Cố gắng lên!',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: highlightColor,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0, delay: 200.ms),
              const Gap(8),
              Text(
                'Bạn đã hoàn thành: ${result.quiz.title}',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),

              const Gap(kSpaceXL),

              // ── Điểm số (Score Card) ──
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
                decoration: BoxDecoration(
                  gradient: highlightGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: highlightColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'ĐIỂM CỦA BẠN',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontSize: 12,
                      ),
                    ),
                    const Gap(8),
                    // Điểm / 10
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          result.scoreOutOf10.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          '/10',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    // Nhận XP
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${result.xpEarned} XP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms).scale(
                    delay: 400.ms,
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    curve: Curves.easeOutBack,
                  ),

              const Gap(kSpaceXL),

              // ── Thống kê chi tiết ──
              Row(
                children: [
                  _ResultStatItem(
                    title: 'Đúng',
                    value: '${result.correctAnswers}',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                    isDark: isDark,
                  ),
                  const Gap(12),
                  _ResultStatItem(
                    title: 'Sai',
                    value: '${result.incorrectAnswers}',
                    icon: Icons.cancel_outlined,
                    color: AppColors.error,
                    isDark: isDark,
                  ),
                  const Gap(12),
                  _ResultStatItem(
                    title: 'Thời gian',
                    value: result.timeSpentFormatted,
                    icon: Icons.timer_outlined,
                    color: AppColors.primary,
                    isDark: isDark,
                  ),
                ],
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2, end: 0, delay: 500.ms),

              const Gap(kSpaceXXL),

              // ── Nút Action ──
              PrimaryButton(
                text: 'Xem lại đáp án',
                icon: Icons.fact_check_outlined,
                onPressed: () => context.push(AppRoutes.quizReviewPath(widget.quizId), extra: result),
              ).animate().fadeIn(delay: 600.ms),
              const Gap(12),
              SecondaryButton(
                text: 'Về trang chủ',
                onPressed: () => context.go(AppRoutes.home),
              ).animate().fadeIn(delay: 700.ms),

              const Gap(kSpaceXL),
            ],
          ),
        ),
      ),
    );
  }
}

// Item hiển thị trong hàng thống kê
class _ResultStatItem extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _ResultStatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const Gap(8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const Gap(2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
