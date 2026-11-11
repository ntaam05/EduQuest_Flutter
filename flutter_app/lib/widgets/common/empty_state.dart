// lib/widgets/common/empty_state.dart
// Widget Empty State — hiển thị khi không có dữ liệu.
// Gồm: icon/emoji lớn, tiêu đề, mô tả, optional button.

import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String emoji; // Emoji lớn thay Lottie (đơn giản hơn)
  final String title; // Tiêu đề
  final String? subtitle; // Mô tả phụ
  final String? buttonText; // Text nút action (null = ẩn)
  final VoidCallback? onAction; // Callback khi nhấn nút

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Emoji lớn
            Text(
              emoji,
              style: const TextStyle(fontSize: 72),
            ),
            const SizedBox(height: 24),
            // Tiêu đề
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            // Mô tả (nếu có)
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            // Action button (nếu có)
            if (buttonText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
