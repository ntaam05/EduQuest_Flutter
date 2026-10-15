// lib/widgets/common/section_header.dart
// Widget tiêu đề section tái sử dụng.
// Hiển thị: tiêu đề + (optional) nút "Xem tất cả"

import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText; // Text nút "Xem tất cả" (null = ẩn)
  final VoidCallback? onAction; // Callback khi nhấn action

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // Nút action (nếu có)
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionText!,
              style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
            ),
          ),
      ],
    );
  }
}
