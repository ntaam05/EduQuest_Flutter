import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import '../../providers/quiz_provider.dart';
import '../../theme/app_colors.dart';

class QuizReviewScreen extends StatelessWidget {
  final String quizId;
  const QuizReviewScreen({super.key, required this.quizId});

  @override
  Widget build(BuildContext context) {
    final result = context.watch<QuizProvider>().lastResult;
    if (result == null || result.quiz.id != quizId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xem lại đáp án')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Không tìm thấy dữ liệu bài làm.'),
              const Gap(12),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Quay lại')),
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Xem lại đáp án')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: result.quiz.questions.length,
        separatorBuilder: (_, __) => const Gap(12),
        itemBuilder: (context, index) {
          final question = result.quiz.questions[index];
          final selected = result.selectedAnswers[question.id];
          final correct = question.correctAnswer;
          final isCorrect = selected != null && selected == correct;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Câu ${index + 1}', style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary)),
                  const Gap(6),
                  Text(question.question, style: theme.textTheme.titleMedium),
                  const Gap(12),
                  ...List.generate(question.options.length, (optionIndex) {
                    final isAnswer = optionIndex == correct;
                    final isUserChoice = optionIndex == selected;
                    Color? color;
                    if (isAnswer) color = AppColors.successContainer;
                    if (isUserChoice && !isAnswer) color = AppColors.errorContainer;
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color ?? theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isAnswer ? AppColors.success : isUserChoice ? AppColors.error : theme.dividerColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text('${String.fromCharCode(65 + optionIndex)}. ${question.options[optionIndex]}')),
                          if (isAnswer) const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                          if (isUserChoice && !isAnswer) const Icon(Icons.cancel, size: 18, color: AppColors.error),
                        ],
                      ),
                    );
                  }),
                  const Gap(4),
                  Text(
                    selected == null ? 'Bạn chưa chọn đáp án.' : isCorrect ? 'Chính xác!' : 'Chưa chính xác.',
                    style: TextStyle(color: isCorrect ? AppColors.success : AppColors.error, fontWeight: FontWeight.w600),
                  ),
                  if (question.explanation?.isNotEmpty == true) ...[
                    const Gap(6),
                    Text('Giải thích: ${question.explanation}', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
