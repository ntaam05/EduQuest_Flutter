// lib/theme/app_colors.dart
// Định nghĩa toàn bộ màu sắc của app tại một chỗ.
// Không hard-code màu trực tiếp trong widget — luôn dùng từ file này.

import 'package:flutter/material.dart';

/// AppColors chứa tất cả màu tĩnh dùng trong app.
/// Với màu phụ thuộc theme (light/dark), hãy dùng Theme.of(context).colorScheme.
abstract class AppColors {
  // ──────────────────────────────────────────
  // PRIMARY PALETTE — Xanh dương tím (Indigo)
  // ──────────────────────────────────────────

  /// Màu chủ đạo — Indigo đậm
  static const Color primary = Color(0xFF5C6BC0);

  /// Màu chủ đạo sáng hơn — dùng cho gradient, hover
  static const Color primaryLight = Color(0xFF7986CB);

  /// Màu chủ đạo tối hơn — dùng cho pressed state
  static const Color primaryDark = Color(0xFF3949AB);

  /// Container màu chủ đạo (nền button, chip)
  static const Color primaryContainer = Color(0xFFE8EAF6);

  // ──────────────────────────────────────────
  // SECONDARY PALETTE — Tím nhạt (Purple)
  // ──────────────────────────────────────────

  /// Màu phụ — Purple
  static const Color secondary = Color(0xFF9C27B0);

  /// Container màu phụ
  static const Color secondaryContainer = Color(0xFFF3E5F5);

  // ──────────────────────────────────────────
  // ACCENT — Amber/Orange (cho gamification)
  // ──────────────────────────────────────────

  /// Màu accent — Amber (dùng cho XP, streak, rank)
  static const Color accent = Color(0xFFFFB300);

  /// Màu accent nhạt
  static const Color accentLight = Color(0xFFFFD54F);

  // ──────────────────────────────────────────
  // SEMANTIC COLORS — Đúng / Sai / Cảnh báo
  // ──────────────────────────────────────────

  /// Màu thành công — Xanh lá
  static const Color success = Color(0xFF4CAF50);

  /// Container màu thành công
  static const Color successContainer = Color(0xFFE8F5E9);

  /// Màu lỗi — Đỏ
  static const Color error = Color(0xFFE53935);

  /// Container màu lỗi
  static const Color errorContainer = Color(0xFFFFEBEE);

  /// Màu cảnh báo — Cam
  static const Color warning = Color(0xFFFF7043);

  /// Container màu cảnh báo
  static const Color warningContainer = Color(0xFFFBE9E7);

  // ──────────────────────────────────────────
  // NEUTRAL — Text / Background / Surface
  // ──────────────────────────────────────────

  /// Background chính của app (Light mode)
  static const Color backgroundLight = Color(0xFFF7F8FC);

  /// Background chính của app (Dark mode)
  static const Color backgroundDark = Color(0xFF121212);

  /// Surface card (Light mode)
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Surface card (Dark mode)
  static const Color surfaceDark = Color(0xFF1E1E2E);

  /// Surface tối hơn một chút (Dark mode — cho shimmer, divider)
  static const Color surfaceDark2 = Color(0xFF2A2A3E);

  // ──────────────────────────────────────────
  // TEXT COLORS
  // ──────────────────────────────────────────

  /// Text chính — Rất tối (Light mode)
  static const Color textPrimary = Color(0xFF1A1A2E);

  /// Text phụ — Xám vừa
  static const Color textSecondary = Color(0xFF6B7280);

  /// Text hint — Xám nhạt (dùng trong TextField hint)
  static const Color textHint = Color(0xFFADB5BD);

  /// Text trên dark background — Trắng
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Text chính trong dark mode
  static const Color textPrimaryDark = Color(0xFFE8EAF6);

  /// Text phụ trong dark mode
  static const Color textSecondaryDark = Color(0xFF9E9E9E);

  // ──────────────────────────────────────────
  // BORDER / DIVIDER
  // ──────────────────────────────────────────

  /// Màu border nhẹ (Light mode)
  static const Color borderLight = Color(0xFFE8ECF0);

  /// Màu border nhẹ (Dark mode)
  static const Color borderDark = Color(0xFF2D2D42);

  // ──────────────────────────────────────────
  // GRADIENTS — Dùng cho header, card nổi bật
  // ──────────────────────────────────────────

  /// Gradient chính — Indigo → Purple
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5C6BC0), Color(0xFF7B1FA2)],
  );

  /// Gradient cho card thống kê
  static const LinearGradient statGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)],
  );

  /// Gradient Amber cho streak/achievement
  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
  );

  /// Gradient xanh lá cho success
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
  );
}
