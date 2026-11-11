// lib/screens/review/review_screen.dart
// Màn hình Ôn tập — hiển thị thư viện quiz.
// Search bar + Filter chips + Danh sách QuizCard.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/quiz.dart';
import '../../providers/quiz_provider.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/quiz/quiz_card.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // Từ khóa tìm kiếm
  QuizStatus? _filterStatus; // null = tất cả, hoặc lọc theo status

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // chỉ chủ bài mới thấy menu này.
  Future<void> _confirmDelete(Quiz quiz) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa bài?'),
        content: Text('Xóa "${quiz.title}" cùng lịch sử làm bài và tệp đã tải lên? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<QuizProvider>().deleteQuiz(quiz.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bài.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa: $error'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quizProvider = context.watch<QuizProvider>();

    // Lọc và tìm kiếm quiz
    List<Quiz> filteredQuizzes = _filterStatus == null
        ? quizProvider.searchQuizzes(_searchQuery)
        : quizProvider
            .filterByStatus(_filterStatus!)
            .where((q) {
              if (_searchQuery.isEmpty) return true;
              final q2 = _searchQuery.toLowerCase();
              return q.title.toLowerCase().contains(q2) ||
                  q.subject.toLowerCase().contains(q2);
            })
            .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createQuiz),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo bài'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AppBar tùy chỉnh ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  kScreenPadding, kSpaceLG, kScreenPadding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ôn tập',
                    style: theme.textTheme.headlineLarge,
                  ).animate().fadeIn(duration: 300.ms),
                  const Gap(4),
                  Text(
                    '${quizProvider.quizzes.length} bài có sẵn',
                    style: theme.textTheme.bodyMedium,
                  ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
                ],
              ),
            ),

            const Gap(kSpaceMD),

            // ── Search Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm bài học...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ).animate().fadeIn(delay: 150.ms, duration: 300.ms),

            const Gap(kSpaceMD),

            // ── Filter Chips ──
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: kScreenPadding),
                children: [
                  _FilterChip(
                    label: 'Tất cả',
                    isSelected: _filterStatus == null,
                    onTap: () => setState(() => _filterStatus = null),
                  ),
                  const Gap(8),
                  _FilterChip(
                    label: 'Chưa làm',
                    isSelected: _filterStatus == QuizStatus.notStarted,
                    onTap: () =>
                        setState(() => _filterStatus = QuizStatus.notStarted),
                  ),
                  const Gap(8),
                  _FilterChip(
                    label: 'Đang làm',
                    isSelected: _filterStatus == QuizStatus.inProgress,
                    onTap: () =>
                        setState(() => _filterStatus = QuizStatus.inProgress),
                  ),
                  const Gap(8),
                  _FilterChip(
                    label: 'Đã hoàn thành',
                    isSelected: _filterStatus == QuizStatus.completed,
                    onTap: () =>
                        setState(() => _filterStatus = QuizStatus.completed),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

            const Gap(kSpaceMD),

            // ── Danh sách Quiz ──
            Expanded(
              child: filteredQuizzes.isEmpty
                  // Empty state khi không có kết quả
                  ? EmptyState(
                      emoji: _searchQuery.isNotEmpty ? '🔍' : '📚',
                      title: _searchQuery.isNotEmpty
                          ? 'Không tìm thấy kết quả'
                          : 'Chưa có bài ôn tập',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'Thử tìm kiếm với từ khóa khác'
                          : 'Hãy upload bài đầu tiên để bắt đầu',
                      buttonText: _searchQuery.isEmpty ? 'Upload bài ngay' : null,
                      onAction: () => context.go(AppRoutes.upload),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        kScreenPadding,
                        0,
                        kScreenPadding,
                        kSpaceXL,
                      ),
                      itemCount: filteredQuizzes.length,
                      separatorBuilder: (_, __) => const Gap(12),
                      itemBuilder: (context, index) {
                        return QuizCard(
                          quiz: filteredQuizzes[index],
                          onTap: () {
                            context.push(AppRoutes.quizPath(filteredQuizzes[index].id));
                          },
                          onDelete: filteredQuizzes[index].isOwner
                              ? () => _confirmDelete(filteredQuizzes[index])
                              : null,
                        )
                            .animate()
                            .fadeIn(
                              delay: Duration(milliseconds: index * 80),
                              duration: 350.ms,
                            )
                            .slideY(
                              begin: 0.1,
                              end: 0,
                              delay: Duration(milliseconds: index * 80),
                              duration: 350.ms,
                            );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Filter Chip tùy chỉnh
// ──────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(kRadiusFull),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : theme.brightness == Brightness.dark
                    ? AppColors.borderDark
                    : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? Colors.white
                : theme.textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
