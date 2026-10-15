// lib/widgets/common/stat_card.dart
// Card hiển thị thống kê nhỏ (số bài đã làm, điểm TB...).
// Hỗ trợ gradient, icon, và animation.

import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String label; // Nhãn (VD: "Bài đã làm")
  final String value; // Giá trị (VD: "24")
  final IconData icon; // Icon
  final Color iconColor; // Màu icon
  final Color iconBgColor; // Màu nền icon
  final bool isHighlighted; // Nổi bật hơn (gradient)

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? const Color(0xFF2D2D42)
              : const Color(0xFFE8ECF0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon với nền màu
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          // Giá trị lớn
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          // Nhãn
          Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
