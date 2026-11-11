// lib/screens/upload/upload_screen.dart
// Màn hình upload tài liệu; backend trích xuất câu hỏi có cấu trúc và lưu dữ liệu vào backend.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/upload_provider.dart';
import '../../routes/app_router.dart';
import '../../theme/app_colors.dart';
import '../../utils/constants.dart';
import '../../widgets/common/primary_button.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uploadProvider = context.watch<UploadProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: kScreenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(kSpaceLG),

              // ── Header ──
              Text(
                'Upload bài',
                style: Theme.of(context).textTheme.headlineLarge,
              ).animate().fadeIn(duration: 300.ms),
              const Gap(4),
              Text(
                'Chọn tài liệu trên thiết bị — hỗ trợ PDF, DOCX, XLSX, TXT',
                style: Theme.of(context).textTheme.bodyMedium,
              ).animate().fadeIn(delay: 100.ms),

              const Gap(kSpaceXL),

              // ── File Picker Zone ──
              _FilePickerZone().animate().fadeIn(delay: 150.ms),

              const Gap(kSpaceLG),


              // ── Form thông tin bài (chỉ hiện khi đã chọn file) ──
              if (uploadProvider.hasFile) ...[
                _QuizInfoForm().animate().fadeIn(duration: 400.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 400.ms,
                    ),
                const Gap(kSpaceLG),
              ],

              // ── Tệp đã tải lên ──
              const _MyUploadsSection(),

              const Gap(kSpaceXL),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Danh sách tệp đã tải lên của tài khoản
// ──────────────────────────────────────────
class _MyUploadsSection extends StatefulWidget {
  const _MyUploadsSection();

  @override
  State<_MyUploadsSection> createState() => _MyUploadsSectionState();
}

class _MyUploadsSectionState extends State<_MyUploadsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UploadProvider>().loadMyUploads();
    });
  }

  String _size(num bytes) {
    final kb = bytes / 1024;
    return kb < 1024 ? '${kb.toStringAsFixed(0)} KB' : '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  String _date(dynamic raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '');
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  IconData _icon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'docx':
        return Icons.description_outlined;
      case 'xlsx':
        return Icons.table_chart_outlined;
      default:
        return Icons.text_snippet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UploadProvider>();
    final theme = Theme.of(context);
    final rows = provider.myUploads;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Tệp đã tải lên', style: theme.textTheme.titleLarge)),
            IconButton(
              tooltip: 'Làm mới',
              onPressed: provider.loadingUploads ? null : () => provider.loadMyUploads(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        if (provider.loadingUploads && rows.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (provider.uploadsError != null && rows.isEmpty)
          Text(provider.uploadsError!, style: const TextStyle(color: AppColors.error))
        else if (rows.isEmpty)
          Text('Bạn chưa tải tệp nào lên.', style: theme.textTheme.bodySmall)
        else
          ...rows.map((row) {
            final extension = row['extension']?.toString() ?? '';
            final questions = (row['questions_count'] as num?)?.toInt() ?? 0;
            final quizId = row['quiz_id']?.toString();
            final title = row['quiz_title']?.toString() ?? row['original_name']?.toString() ?? 'Tệp';
            final sizeBytes = (row['size_bytes'] as num?) ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_icon(extension), color: AppColors.primary),
                title: Text(row['original_name']?.toString() ?? title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$title • $questions câu • ${_size(sizeBytes)} • ${_date(row['uploaded_at'])}'),
                trailing: questions > 0 && quizId != null ? const Icon(Icons.chevron_right) : const Text('Bản nháp'),
                onTap: questions > 0 && quizId != null ? () => context.push(AppRoutes.quizPath(quizId)) : null,
              ),
            );
          }),
      ],
    );
  }
}

// ──────────────────────────────────────────
// Khu vực chọn file
// ──────────────────────────────────────────
class _FilePickerZone extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final uploadProvider = context.watch<UploadProvider>();

    // Nếu đã chọn file: hiện thông tin file
    if (uploadProvider.hasFile) {
      return _SelectedFileCard(provider: uploadProvider, isDark: isDark);
    }

    // Chưa chọn file: hiện zone kéo thả/nhấn để chọn
    return GestureDetector(
      onTap: () => _pickFile(context),
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark2 : AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            style: BorderStyle.solid,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon upload
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file_outlined,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const Gap(kSpaceMD),
            Text(
              'Nhấn để chọn tài liệu',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(4),
            Text(
              'PDF, DOCX, XLSX, TXT — Tối đa 10MB',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // Mở file picker dialog
  Future<void> _pickFile(BuildContext context) async {
    final uploadProvider = context.read<UploadProvider>();

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Chọn tài liệu câu hỏi',
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'xlsx', 'txt'],
        withData: kIsWeb,
      );
      if (!context.mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size == 0 || file.size > 10 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tệp phải có nội dung và dung lượng tối đa 10 MB.')),
        );
        return;
      }
      uploadProvider.onFileSelected(
        name: file.name,
        path: kIsWeb ? '' : (file.path ?? ''),
        bytes: file.bytes,
        sizeBytes: file.size,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được tài liệu. Hãy chọn lại tệp.')),
      );
    }
  }
}

// Card hiển thị file đã chọn
class _SelectedFileCard extends StatelessWidget {
  final UploadProvider provider;
  final bool isDark;

  const _SelectedFileCard({required this.provider, required this.isDark});

  // Lấy màu theo extension
  Color _getExtColor(String? ext) {
    switch (ext) {
      case 'pdf':
        return AppColors.error;
      case 'docx':
        return AppColors.primary;
      case 'xlsx':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  // Lấy icon theo extension
  IconData _getExtIcon(String? ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'docx':
        return Icons.description_outlined;
      case 'xlsx':
        return Icons.table_chart_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = provider.selectedFileExtension;
    final color = _getExtColor(ext);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // File icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getExtIcon(ext), color: color, size: 28),
          ),
          const Gap(kSpaceMD),
          // Tên file và size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.selectedFileName ?? '',
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (ext ?? '').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const Gap(8),
                    Text(
                      provider.fileSizeDisplay,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Nút xóa file
          IconButton(
            onPressed: () => context.read<UploadProvider>().removeFile(),
            icon: Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            tooltip: 'Xóa file',
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Form thông tin bài quiz
// ──────────────────────────────────────────
class _QuizInfoForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uploadProvider = context.watch<UploadProvider>();
    final isUploading = uploadProvider.status == UploadStatus.uploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thông tin bài', style: theme.textTheme.headlineSmall),
        const Gap(kSpaceMD),

        // Tên bài
        _FormField(
          label: 'Tên bài *',
          initialValue: uploadProvider.quizTitle,
          hint: 'VD: Flutter Cơ Bản',
          onChanged: (v) => context.read<UploadProvider>().updateTitle(v),
        ),

        const Gap(kSpaceMD),

        // Môn học
        _FormField(
          label: 'Môn học *',
          initialValue: uploadProvider.quizSubject,
          hint: 'VD: Lập trình di động',
          onChanged: (v) => context.read<UploadProvider>().updateSubject(v),
        ),

        const Gap(kSpaceMD),

        // Mô tả
        _FormField(
          label: 'Mô tả',
          initialValue: uploadProvider.quizDescription,
          hint: 'Mô tả ngắn về nội dung bài...',
          maxLines: 3,
          onChanged: (v) =>
              context.read<UploadProvider>().updateDescription(v),
        ),

        const Gap(kSpaceXL),

        if (uploadProvider.errorMessage != null) ...[
          Text(uploadProvider.errorMessage!, style: const TextStyle(color: AppColors.error)),
          const Gap(kSpaceSM),
        ],

        // Nút Upload
        PrimaryButton(
          text: 'Upload bài',
          isLoading: isUploading,
          icon: Icons.cloud_upload_outlined,
          onPressed:
              uploadProvider.quizTitle.isNotEmpty && !isUploading
                  ? () => _handleUpload(context)
                  : null,
        ),
      ],
    );
  }

  Future<void> _handleUpload(BuildContext context) async {
    final uploadProvider = context.read<UploadProvider>();
    final quizProvider = context.read<QuizProvider>();

    // Gửi file thật lên API và lưu file cùng metadata xuống database.
    final draft = await uploadProvider.uploadQuiz();

    if (draft != null && context.mounted) {
      // Bài có câu hỏi hợp lệ tự xuất hiện trong thư viện; bài chưa nhận diện được vẫn là bản nháp.
      await quizProvider.loadQuizzes();
      if (context.mounted) _showSuccessDialog(context, draft.title, draft.id);
    }
  }

  void _showSuccessDialog(BuildContext context, String quizTitle, String quizId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon thành công
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.successContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success,
                size: 40,
              ),
            ),
            const Gap(kSpaceMD),
            const Text(
              'Upload thành công! 🎉',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              context.read<UploadProvider>().lastUploadMessage ?? 'Đã lưu tài liệu lên máy chủ.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const Gap(8),
            Text(
              'Số câu đã tạo: ${context.read<UploadProvider>().lastUploadQuestionCount}',
              style: const TextStyle(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            if (context.read<UploadProvider>().lastParsingMode == 'definition-based') ...[
              const Gap(8),
              const Text('Chế độ: tạo câu hỏi từ các định nghĩa đã trích xuất.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
            if (context.read<UploadProvider>().lastUploadWarnings.isNotEmpty) ...[
              const Gap(8),
              ...context.read<UploadProvider>().lastUploadWarnings.map((warning) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(warning, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<UploadProvider>().reset();
            },
            child: const Text('Đã hiểu'),
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
      ),
    );
  }
}

// ──────────────────────────────────────────
// FormField tái sử dụng
// ──────────────────────────────────────────
class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final String initialValue;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _FormField({
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const Gap(6),
        TextFormField(
          initialValue: initialValue,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
