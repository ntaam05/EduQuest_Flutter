// lib/widgets/quiz/quiz_card.dart
// Card hiển thị thông tin tóm tắt của một bài quiz.
// Dùng ở màn hình Review và Home (Recent Quizzes).

import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../models/quiz.dart';
import '../../theme/app_colors.dart';

class QuizCard extends StatefulWidget {
  final Quiz quiz;
  final VoidCallback onTap; // Callback khi nhấn "Làm bài"
  final VoidCallback? onDelete; // Có giá trị → hiện menu "Xóa bài" (chỉ chủ bài)

  const QuizCard({super.key, required this.quiz, required this.onTap, this.onDelete});

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  bool _isPressed = false; // Tracking press cho scale animation

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quiz = widget.quiz;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0, // Nhấn nhẹ khi tap
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Icon + Tên bài + Status chip ──
              Row(
                children: [
                  // Emoji icon trong container tròn
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        quiz.iconEmoji ?? '📚',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tên bài và môn học
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: theme.textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quiz.subject,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status chip
                  _StatusChip(status: quiz.status),
                  if (widget.onDelete != null)
                    PopupMenuButton<String>(
                      tooltip: 'Tùy chọn',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded, size: 20),
                      onSelected: (value) {
                        if (value == 'delete') widget.onDelete!();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete', child: Text('Xóa bài')),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Thông tin: số câu + thời gian ──
              Row(
                children: [
                  Icon(Icons.quiz_outlined,
                      size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    '${quiz.questionCount} câu',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time_outlined,
                      size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    '${quiz.durationMinutes} phút',
                    style: theme.textTheme.bodySmall,
                  ),
                  // Điểm gần nhất (nếu đã làm)
                  if (quiz.lastScore != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${quiz.lastScore!.toStringAsFixed(1)}/10',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // ── Progress bar ──
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiến độ',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        '${(quiz.progress * 100).toInt()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // LinearPercentIndicator từ package percent_indicator
                  LinearPercentIndicator(
                    percent: quiz.progress,
                    lineHeight: 6,
                    backgroundColor: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                    progressColor: AppColors.primary,
                    barRadius: const Radius.circular(4),
                    padding: EdgeInsets.zero,
                    animation: true, // Animate khi card xuất hiện
                    animationDuration: 600,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Button "Làm bài" ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onTap,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    quiz.status == QuizStatus.notStarted
                        ? 'Bắt đầu'
                        : quiz.status == QuizStatus.inProgress
                            ? 'Tiếp tục'
                            : 'Làm lại',
                  ),
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
// Chip hiển thị trạng thái quiz
// ──────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final QuizStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case QuizStatus.notStarted:
        bgColor = AppColors.primaryContainer;
        textColor = AppColors.primary;
        label = 'Chưa làm';
        break;
      case QuizStatus.inProgress:
        bgColor = AppColors.warningContainer;
        textColor = AppColors.warning;
        label = 'Đang làm';
        break;
      case QuizStatus.completed:
        bgColor = AppColors.successContainer;
        textColor = AppColors.success;
        label = 'Hoàn thành';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
