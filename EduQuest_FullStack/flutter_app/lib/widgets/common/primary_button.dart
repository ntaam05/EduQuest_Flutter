// lib/widgets/common/primary_button.dart
// Nút chính của app (màu primary, bo góc chuẩn).
// Hỗ trợ loading state và disabled state.

import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // null = disabled
  final bool isLoading; // Hiện loading spinner
  final IconData? icon; // Optional icon trước text
  final double? width; // null = full width
  final EdgeInsets? padding;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity, // Mặc định full width
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed, // Disable khi loading
        style: ElevatedButton.styleFrom(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
        child: isLoading
            // Loading state: spinner trắng
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            // Normal state: icon (optional) + text
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(text),
                ],
              ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Nút phụ (outlined style)
// ──────────────────────────────────────────
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? width;

  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(text),
          ],
        ),
      ),
    );
  }
}
