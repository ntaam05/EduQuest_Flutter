// lib/routes/app_router.dart
// Cấu hình routing toàn bộ ứng dụng bằng go_router.
// Shell Route cho Bottom Navigation — 5 tab chính.
// Sub-routes cho Quiz, Room, Profile.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/main_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/review/review_screen.dart';
import '../screens/upload/upload_screen.dart';
import '../screens/room/room_screen.dart';
import '../screens/room/room_lobby_screen.dart';
import '../screens/room/room_game_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/quiz/quiz_screen.dart';
import '../screens/quiz/quiz_result_screen.dart';
import '../screens/quiz/quiz_review_screen.dart';
import '../screens/quiz/quiz_create_screen.dart';
import '../screens/quiz/quiz_history_screen.dart';

// ──────────────────────────────────────────
// ROUTE NAMES — dùng constant để tránh typo
// ──────────────────────────────────────────
class AppRoutes {
  // Bottom tabs
  static const String home = '/home';
  static const String review = '/review';
  static const String upload = '/upload';
  static const String rooms = '/rooms';
  static const String profile = '/profile';

  // Đăng nhập / Đăng ký
  static const String login = '/login';

  // Tạo bài thủ công / lịch sử làm bài
  static const String createQuiz = '/create-quiz';
  static const String history = '/history';

  // Quiz sub-routes
  static const String quiz = '/quiz/:id';
  static const String quizResult = '/quiz/:id/result';
  static const String quizReview = '/quiz/:id/review';

  // Room sub-routes
  static const String roomCreate = '/room/create';
  static const String roomJoin = '/room/join';
  static const String roomLobby = '/room/:code';
  static const String roomGame = '/room/:code/game';
  static const String roomResult = '/room/:code/result';

  // Profile sub-routes
  static const String statistics = '/profile/statistics';
  static const String settings = '/profile/settings';

  // Helper để tạo path với ID
  static String quizPath(String id) => '/quiz/$id';
  static String quizResultPath(String id) => '/quiz/$id/result';
  static String quizReviewPath(String id) => '/quiz/$id/review';
  static String roomLobbyPath(String code) => '/room/$code';
  static String roomGamePath(String code) => '/room/$code/game';
  static String roomResultPath(String code) => '/room/$code/result';
}

// ──────────────────────────────────────────
// ROUTER CONFIGURATION
// ──────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home, // Mở app ở tab Home

  // Chưa đăng nhập → luôn về màn Đăng nhập; đã đăng nhập mà đang ở màn Đăng nhập → về Trang chủ.
  refreshListenable: ApiClient.instance.loggedIn,
  redirect: (context, state) {
    final loggedIn = ApiClient.instance.loggedIn.value;
    final atLogin = state.matchedLocation == AppRoutes.login;
    if (!loggedIn && !atLogin) return AppRoutes.login;
    if (loggedIn && atLogin) return AppRoutes.home;
    return null;
  },

  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const AuthScreen(),
    ),
    // ─────────────────────────────────────
    // SHELL ROUTE — Bottom Navigation Shell
    // Bao bọc 5 tab chính, giữ state khi chuyển tab
    // ─────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) {
        // MainScreen là shell chứa BottomNavigation
        return MainScreen(child: child);
      },
      routes: [
        // Tab 1: Home
        GoRoute(
          path: AppRoutes.home,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        // Tab 2: Review
        GoRoute(
          path: AppRoutes.review,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ReviewScreen(),
          ),
        ),
        // Tab 3: Upload (mở như modal)
        GoRoute(
          path: AppRoutes.upload,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: UploadScreen(),
          ),
        ),
        // Tab 4: Rooms
        GoRoute(
          path: AppRoutes.rooms,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: RoomScreen(),
          ),
        ),
        // Tab 5: Profile
        GoRoute(
          path: AppRoutes.profile,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.roomLobby,
      builder: (context, state) => RoomLobbyScreen(roomCode: state.pathParameters['code']!),
    ),
    GoRoute(
      path: AppRoutes.roomGame,
      builder: (context, state) => RoomGameScreen(roomCode: state.pathParameters['code']!),
    ),
    // ─────────────────────────────────────
    // FULL SCREEN ROUTES (Không có Bottom Nav)
    // ─────────────────────────────────────
    GoRoute(
      path: AppRoutes.quiz,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return QuizScreen(quizId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.quizResult,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return QuizResultScreen(quizId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.createQuiz,
      builder: (context, state) => const QuizCreateScreen(),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const QuizHistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.quizReview,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return QuizReviewScreen(quizId: id);
      },
    ),
  ],

  // Xử lý lỗi route không tìm thấy
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('404', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('Không tìm thấy trang: ${state.uri.path}'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Về trang chủ'),
          ),
        ],
      ),
    ),
  ),
);
