// lib/screens/quiz/quiz_history_screen.dart
// Lịch sử làm bài.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/quiz_provider.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<QuizProvider>().loadAttempts();
    });
  }

  /// Server trả giờ UTC nhưng không có hậu tố "Z" → tự thêm để đổi đúng sang giờ máy.
  String _formatDate(dynamic raw) {
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return '';
    final hasZone = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(text);
    final value = DateTime.tryParse(hasZone ? text : '${text}Z')?.toLocal();
    if (value == null) return text;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizProvider>();
    final theme = Theme.of(context);
    final rows = provider.attempts;

    Widget body;
    if (provider.loadingAttempts && rows.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (provider.attemptsError != null && rows.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(provider.attemptsError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: provider.loadAttempts, child: const Text('Thử lại')),
          ]),
        ),
      );
    } else if (rows.isEmpty) {
      body = const Center(child: Text('Bạn chưa làm bài nào.'));
    } else {
      body = RefreshIndicator(
        onRefresh: provider.loadAttempts,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(kScreenPadding),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final row = rows[index];
            final submitted = row['submitted_at'] != null;
            final percent = (row['score_percent'] as num?)?.toDouble() ?? 0;
            final correct = (row['correct_answers'] as num?)?.toInt() ?? 0;
            final total = (row['total_questions'] as num?)?.toInt() ?? 0;
            final quizId = row['quiz_id']?.toString();
            final color = !submitted
                ? AppColors.warning
                : percent >= 80
                    ? AppColors.success
                    : percent >= 50
                        ? AppColors.primary
                        : AppColors.error;
            return Card(
              child: ListTile(
                onTap: quizId == null ? null : () => context.push(AppRoutes.quizPath(quizId)),
                title: Text(row['quiz_title']?.toString() ?? 'Bài thi', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  submitted
                      ? '${_formatDate(row['submitted_at'])} • đúng $correct/$total câu'
                      : '${_formatDate(row['started_at'])} • chưa nộp bài',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    submitted ? '${percent.toStringAsFixed(0)}%' : '--',
                    style: TextStyle(fontWeight: FontWeight.w800, color: color),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch sử làm bài', style: theme.textTheme.titleLarge),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: provider.loadingAttempts ? null : provider.loadAttempts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}
