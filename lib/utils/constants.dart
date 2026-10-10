// lib/utils/constants.dart
// Các hằng số dùng chung trong toàn ứng dụng.
// Tập trung tại một nơi để dễ thay đổi.

/// Tên ứng dụng — đổi tên tại đây để áp dụng toàn bộ
const String kAppName = 'QuizUp';
const String kAppTagline = 'Học thông minh, thi tự tin';
const String kAppVersion = '1.0.0';

// ──────────────────────────────────────────
// Border Radius
// ──────────────────────────────────────────
const double kRadiusXS = 8.0;
const double kRadiusSM = 12.0;
const double kRadiusMD = 16.0;
const double kRadiusLG = 24.0;
const double kRadiusXL = 32.0;
const double kRadiusFull = 100.0; // Để làm pill shape

// ──────────────────────────────────────────
// Spacing / Padding
// ──────────────────────────────────────────
const double kSpaceXS = 4.0;
const double kSpaceSM = 8.0;
const double kSpaceMD = 16.0;
const double kSpaceLG = 24.0;
const double kSpaceXL = 32.0;
const double kSpaceXXL = 48.0;

/// Padding ngang chuẩn của màn hình
const double kScreenPadding = 20.0;

// ──────────────────────────────────────────
// Animation Duration
// ──────────────────────────────────────────
const Duration kAnimFast = Duration(milliseconds: 200);
const Duration kAnimMedium = Duration(milliseconds: 350);
const Duration kAnimSlow = Duration(milliseconds: 500);
const Duration kAnimVerySlow = Duration(milliseconds: 800);

// ──────────────────────────────────────────
// Quiz Settings
// ──────────────────────────────────────────
const int kDefaultQuizDuration = 15; // Phút
const int kMaxRoomPlayers = 10;

// ──────────────────────────────────────────
// Mock Room
// ──────────────────────────────────────────
/// Mã phòng mock hợp lệ để test tính năng join
const String kValidMockRoomCode = 'ABCD12';
