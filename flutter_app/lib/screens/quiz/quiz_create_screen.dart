// lib/screens/quiz/quiz_create_screen.dart
// Tạo bài trắc nghiệm thủ công.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/quiz_provider.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/primary_button.dart';

class _QuestionDraft {
  final TextEditingController text = TextEditingController();
  final TextEditingController explanation = TextEditingController();
  final List<TextEditingController> options =
      List.generate(4, (_) => TextEditingController());
  int correct = 0;

  void dispose() {
    text.dispose();
    explanation.dispose();
    for (final controller in options) {
      controller.dispose();
    }
  }
}

class QuizCreateScreen extends StatefulWidget {
  const QuizCreateScreen({super.key});

  @override
  State<QuizCreateScreen> createState() => _QuizCreateScreenState();
}

class _QuizCreateScreenState extends State<QuizCreateScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _subject = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final List<_QuestionDraft> _questions = [_QuestionDraft()];
  double _duration = 15;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _description.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  void _addQuestion() => setState(() => _questions.add(_QuestionDraft()));

  void _removeQuestion(int index) {
    if (_questions.length <= 1) return;
    setState(() => _questions.removeAt(index).dispose());
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final subject = _subject.text.trim();
    if (title.isEmpty || subject.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên bài và môn học.');
      return;
    }

    final payload = <Map<String, dynamic>>[];
    for (var i = 0; i < _questions.length; i++) {
      final draft = _questions[i];
      final text = draft.text.text.trim();
      if (text.isEmpty) {
        setState(() => _error = 'Câu ${i + 1}: chưa nhập nội dung câu hỏi.');
        return;
      }
      // Bỏ qua phương án để trống; tính lại vị trí của đáp án đúng.
      final options = <String>[];
      int? correctIndex;
      for (var j = 0; j < draft.options.length; j++) {
        final value = draft.options[j].text.trim();
        if (value.isEmpty) continue;
        if (j == draft.correct) correctIndex = options.length;
        options.add(value);
      }
      if (options.length < 2) {
        setState(() => _error = 'Câu ${i + 1}: cần ít nhất 2 phương án.');
        return;
      }
      if (correctIndex == null) {
        setState(() => _error = 'Câu ${i + 1}: phương án được chọn là đáp án đúng đang để trống.');
        return;
      }
      final explanation = draft.explanation.text.trim();
      payload.add({
        'text': text,
        'options': options.map((option) => {'text': option}).toList(),
        'correct_answer_index': correctIndex,
        'explanation': explanation.isEmpty ? null : explanation,
      });
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final quiz = await context.read<QuizProvider>().createQuiz(
            title: title,
            subject: subject,
            description: _description.text,
            durationMinutes: _duration.round(),
            iconEmoji: '📝',
            questions: payload,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã tạo bài "${quiz.title}" với ${quiz.questionCount} câu.')),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.review);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo bài thủ công')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(kScreenPadding),
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Tên bài *', hintText: 'VD: Ôn tập Cơ sở dữ liệu'),
            ),
            const Gap(kSpaceMD),
            TextField(
              controller: _subject,
              decoration: const InputDecoration(labelText: 'Môn học *', hintText: 'VD: Cơ sở dữ liệu'),
            ),
            const Gap(kSpaceMD),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Mô tả (không bắt buộc)'),
            ),
            const Gap(kSpaceMD),
            Text('Thời gian làm bài: ${_duration.round()} phút', style: theme.textTheme.titleMedium),
            Slider(
              min: 5,
              max: 120,
              divisions: 23,
              value: _duration,
              label: '${_duration.round()} phút',
              onChanged: (value) => setState(() => _duration = value),
            ),
            const Gap(kSpaceSM),
            Text('Câu hỏi (${_questions.length})', style: theme.textTheme.titleLarge),
            const Gap(kSpaceSM),
            for (var i = 0; i < _questions.length; i++) _buildQuestionCard(theme, i),
            OutlinedButton.icon(
              onPressed: _saving ? null : _addQuestion,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm câu hỏi'),
            ),
            if (_error != null) ...[
              const Gap(kSpaceMD),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const Gap(kSpaceLG),
            PrimaryButton(
              text: 'Lưu bài',
              icon: Icons.save_outlined,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const Gap(kSpaceXL),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(ThemeData theme, int index) {
    final draft = _questions[index];
    return Card(
      key: ObjectKey(draft),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Câu ${index + 1}', style: theme.textTheme.titleMedium)),
                if (_questions.length > 1)
                  IconButton(
                    tooltip: 'Xóa câu này',
                    onPressed: _saving ? null : () => _removeQuestion(index),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
              ],
            ),
            TextField(
              controller: draft.text,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Nội dung câu hỏi *'),
            ),
            const Gap(kSpaceSM),
            Text('Chạm vào dấu tích để chọn đáp án đúng', style: theme.textTheme.bodySmall),
            for (var j = 0; j < draft.options.length; j++)
              Row(
                children: [
                  IconButton(
                    tooltip: 'Đặt làm đáp án đúng',
                    onPressed: () => setState(() => draft.correct = j),
                    icon: Icon(
                      draft.correct == j ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: draft.correct == j ? AppColors.success : null,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: draft.options[j],
                      decoration: InputDecoration(hintText: 'Phương án ${String.fromCharCode(65 + j)}'),
                    ),
                  ),
                ],
              ),
            const Gap(kSpaceSM),
            TextField(
              controller: draft.explanation,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Giải thích (không bắt buộc)'),
            ),
          ],
        ),
      ),
    );
  }
}
