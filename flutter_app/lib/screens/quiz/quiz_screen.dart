// lib/screens/quiz/quiz_screen.dart
// Màn hình làm bài chính.
// Chứa Timer count down, Question content, và Question options.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/quiz/question_option.dart';
import '../../routes/app_router.dart';

class QuizScreen extends StatefulWidget {
  final String quizId;

  const QuizScreen({super.key, required this.quizId});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Timer? _timer;
  Timer? _autoAdvanceTimer;
  bool _autoAdvance = true; // Tự lướt sang câu kế tiếp sau khi chọn đáp án
  int _remainingSeconds = 0;
  bool _isInit = false;
  bool _isReady = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_initializeQuiz(context.read<QuizProvider>()));
      });
    }
  }

  Future<void> _initializeQuiz(QuizProvider provider) async {
    // Đợi danh sách thật từ API trước khi tạo lượt thi để tránh gửi ID câu hỏi mock.
    await provider.loadQuizzes();
    if (!mounted) return;
    final matches = provider.quizzes.where((item) => item.id == widget.quizId);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy bài thi trên máy chủ.')),
      );
      context.go(AppRoutes.home);
      return;
    }
    final quiz = matches.first;
    try {
      await provider.startQuiz(quiz);
      if (!mounted) return;
      setState(() {
        _remainingSeconds = quiz.durationMinutes * 60;
        _isReady = true;
      });
      _startTimer();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể bắt đầu bài thi: $error'), backgroundColor: AppColors.error),
      );
      context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  /// Sau khi trả lời một câu lần đầu: chờ một nhịp ngắn rồi tự sang câu tiếp theo.
  /// Câu cuối không tự nộp bài (tránh nộp nhầm), chỉ nhắc người dùng.
  void _scheduleAutoAdvance(QuizProvider provider, int questionId) {
    _autoAdvanceTimer?.cancel();
    if (!_autoAdvance) return;
    if (provider.isLastQuestion) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Đã trả lời câu cuối — nhấn "Nộp bài" để hoàn tất.'),
          duration: Duration(seconds: 2),
        ));
      return;
    }
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (provider.currentQuestion?.id == questionId) provider.nextQuestion();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        // Hết giờ
        _timer?.cancel();
        _submitQuiz(context, timeOut: true);
      }
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Confirm trước khi nộp
  Future<void> _onConfirmSubmit(BuildContext context) async {
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nộp bài?'),
        content: const Text('Bạn có chắc chắn muốn nộp bài ngay bây giờ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );

    if (shouldSubmit == true && context.mounted) {
      _submitQuiz(context);
    }
  }

  Future<void> _submitQuiz(BuildContext context, {bool timeOut = false}) async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    _timer?.cancel();
    final quizProvider = context.read<QuizProvider>();
    
    // Nếu hết giờ, hiển thị thông báo
    if (timeOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Đã hết thời gian làm bài!'),
          backgroundColor: AppColors.warning,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Nộp bài lên server; điểm số trả về từ API là nguồn dữ liệu chính thức.
    try {
      await quizProvider.submitQuiz();
      if (context.mounted) context.go(AppRoutes.quizResultPath(widget.quizId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể nộp bài: $error'), backgroundColor: AppColors.error),
        );
      }
      _isSubmitting = false;
      if (mounted && _remainingSeconds > 0) _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quizProvider = context.watch<QuizProvider>();
    final quiz = quizProvider.currentQuiz;
    final question = quizProvider.currentQuestion;

    if (!_isReady || quiz == null || question == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isTimeRunningOut = _remainingSeconds <= 60; // Dưới 1 phút -> đỏ

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (Tên bài + Timer) ──
            Padding(
              padding: const EdgeInsets.all(kScreenPadding),
              child: Row(
                children: [
                  // Nút Exit
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _onExit(context),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? AppColors.surfaceDark2 : AppColors.primaryContainer,
                    ),
                  ),
                  const Gap(kSpaceSM),
                  // Thông tin
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Câu ${quizProvider.currentQuestionIndex + 1}/${quiz.questions.length}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // Bật/tắt tự chuyển câu
                  IconButton(
                    tooltip: _autoAdvance ? 'Tự chuyển câu: Bật' : 'Tự chuyển câu: Tắt',
                    icon: Icon(
                      _autoAdvance ? Icons.fast_forward_rounded : Icons.pause_circle_outline_rounded,
                      color: _autoAdvance ? AppColors.primary : null,
                    ),
                    onPressed: () {
                      _autoAdvanceTimer?.cancel();
                      setState(() => _autoAdvance = !_autoAdvance);
                    },
                  ),
                  const Gap(kSpaceSM),
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isTimeRunningOut
                          ? AppColors.errorContainer
                          : (isDark ? AppColors.surfaceDark2 : AppColors.backgroundLight),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isTimeRunningOut
                            ? AppColors.error
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: isTimeRunningOut ? AppColors.error : AppColors.primary,
                        ),
                        const Gap(6),
                        Text(
                          _formattedTime,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isTimeRunningOut ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Progress Bar ──
            LinearPercentIndicator(
              percent: quizProvider.quizProgress,
              lineHeight: 4,
              backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
              progressColor: AppColors.primary,
              padding: EdgeInsets.zero,
              animation: true,
              animateFromLastPercent: true,
            ),

            // ── Question Body (có AnimatedSwitcher) ──
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                // Dùng ID câu hỏi làm key để force re-build & animate khi đổi câu
                child: SingleChildScrollView(
                  key: ValueKey<int>(question.id),
                  padding: const EdgeInsets.all(kScreenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Gap(kSpaceMD),
                      // Nội dung câu hỏi
                      Text(
                        question.question,
                        style: theme.textTheme.headlineSmall?.copyWith(height: 1.4),
                      ),
                      const Gap(kSpaceXL),

                      // Danh sách lựa chọn
                      ...List.generate(question.options.length, (index) {
                        final optionText = question.options[index];
                        final indexLabel = String.fromCharCode(65 + index); // A, B, C, D
                        final isSelected = quizProvider.currentSelectedAnswer == index;

                        return QuestionOption(
                          indexLabel: indexLabel,
                          text: optionText,
                          isSelected: isSelected,
                          onTap: () {
                            final wasAnswered = quizProvider.currentSelectedAnswer != null;
                            quizProvider.selectAnswer(question.id, index);
                            if (!wasAnswered) _scheduleAutoAdvance(quizProvider, question.id);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom Controls ──
            Container(
              padding: const EdgeInsets.all(kScreenPadding),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Nút Câu trước
                  Expanded(
                    child: SecondaryButton(
                      text: 'Câu trước',
                      onPressed: quizProvider.currentQuestionIndex > 0
                          ? () {
                              _autoAdvanceTimer?.cancel();
                              quizProvider.previousQuestion();
                            }
                          : null,
                    ),
                  ),
                  const Gap(kSpaceMD),
                  // Nút Câu tiếp / Nộp bài
                  Expanded(
                    child: PrimaryButton(
                      text: quizProvider.isLastQuestion ? 'Nộp bài' : 'Câu tiếp',
                      onPressed: () {
                        if (quizProvider.isLastQuestion) {
                          _onConfirmSubmit(context);
                        } else {
                          _autoAdvanceTimer?.cancel();
                          quizProvider.nextQuestion();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog thoát khi đang làm
  void _onExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát bài?'),
        content: const Text('Tiến độ của bạn sẽ không được lưu. Bạn có chắc chắn muốn thoát?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tiếp tục làm'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop(); // Go back (ví dụ về trang detail)
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Thoát', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
