// lib/screens/main_screen.dart
// Navigation Shell — bọc 5 tab chính với Bottom Navigation Bar.
// Nút Upload ở giữa nổi bật hơn (FloatingActionButton style).
// Sử dụng BottomAppBar + FAB kết hợp.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_router.dart';
import '../theme/app_colors.dart';

class MainScreen extends StatelessWidget {
  /// Widget nội dung của tab hiện tại (được inject bởi ShellRoute)
  final Widget child;

  const MainScreen({super.key, required this.child});

  // Xác định tab index hiện tại từ current route
  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/review')) return 1;
    if (location.startsWith('/upload')) return 2;
    if (location.startsWith('/rooms')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0; // Mặc định Home
  }

  // Chuyển tab khi nhấn icon
  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.review);
        break;
      case 2:
        context.go(AppRoutes.upload);
        break;
      case 3:
        context.go(AppRoutes.rooms);
        break;
      case 4:
        context.go(AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Màu surface cho navigation bar
    final navBgColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      // Nội dung tab hiện tại
      body: child,

      // ─── Bottom Navigation Bar ───────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBgColor,
          // Đường kẻ trên cùng của nav bar
          border: Border(
            top: BorderSide(color: borderColor, width: 1),
          ),
          // Shadow nhẹ phía trên
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 72, // Tăng chiều cao để không bị overflow
            child: Row(
              children: [
                // Tab 1: Home
                _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Trang chủ',
                  isActive: currentIndex == 0,
                  onTap: () => _onTabTapped(context, 0),
                ),
                // Tab 2: Review
                _NavItem(
                  icon: Icons.menu_book_outlined,
                  activeIcon: Icons.menu_book_rounded,
                  label: 'Ôn tập',
                  isActive: currentIndex == 1,
                  onTap: () => _onTabTapped(context, 1),
                ),

                // Tab 3: Upload — Nút đặc biệt ở giữa
                _UploadNavButton(
                  isActive: currentIndex == 2,
                  onTap: () => _onTabTapped(context, 2),
                ),

                // Tab 4: Rooms
                _NavItem(
                  icon: Icons.emoji_events_outlined,
                  activeIcon: Icons.emoji_events_rounded,
                  label: 'Phòng',
                  isActive: currentIndex == 3,
                  onTap: () => _onTabTapped(context, 3),
                ),
                // Tab 5: Profile
                _NavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Hồ sơ',
                  isActive: currentIndex == 4,
                  onTap: () => _onTabTapped(context, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Widget: Tab thường (không phải Upload)
// ──────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon; // Icon khi không active
  final IconData activeIcon; // Icon khi active
  final String label; // Label bên dưới
  final bool isActive; // Đang ở tab này không
  final VoidCallback onTap; // Callback khi nhấn

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.5);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Indicator dot phía trên icon khi active
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 20 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Icon
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? activeColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 2),
            // Label
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? activeColor : inactiveColor,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Widget: Nút Upload đặc biệt ở giữa
// Nổi bật hơn các tab khác — gradient + shadow
// ──────────────────────────────────────────
class _UploadNavButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _UploadNavButton({required this.isActive, required this.onTap});

  @override
  State<_UploadNavButton> createState() => _UploadNavButtonState();
}

class _UploadNavButtonState extends State<_UploadNavButton> {
  bool _isPressed = false; // Tracking press state cho animation

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nút tròn với gradient — scale animation khi nhấn
            AnimatedScale(
              scale: _isPressed ? 0.92 : 1.0, // Scale nhẹ khi nhấn
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  // Gradient xanh → tím
                  gradient: widget.isActive
                      ? AppColors.statGradient
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  // Shadow đẹp
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
