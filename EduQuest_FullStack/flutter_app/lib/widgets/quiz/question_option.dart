// lib/widgets/quiz/question_option.dart
// Widget hiển thị 1 lựa chọn đáp án trong lúc làm bài.
// Hỗ trợ highlight khi chọn và có animation nhẹ.

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';

class QuestionOption extends StatelessWidget {
  final String indexLabel; // A, B, C, D
  final String text; // Nội dung đáp án
  final bool isSelected; // Trạng thái có đang được chọn không
  final VoidCallback onTap;

  const QuestionOption({
    super.key,
    required this.indexLabel,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Màu sắc thay đổi theo trạng thái isSelected
    final bgColor = isSelected
        ? AppColors.primaryContainer
        : (isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight);

    final borderColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.borderDark : AppColors.borderLight);

    final textColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chữ cái A, B, C, D
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.surfaceDark : AppColors.backgroundLight),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    indexLabel,
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Nội dung đáp án
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2), // Căn chỉnh giữa text và index
                  child: Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
              // Radio Icon phía bên phải
              if (isSelected)
                const Icon(
                  Icons.radio_button_checked_rounded,
                  color: AppColors.primary,
                  size: 24,
                )
              else
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
