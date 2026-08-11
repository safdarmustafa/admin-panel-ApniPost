import 'package:apnipost_admin/features/categories/domain/category.dart';
import 'package:apnipost_admin/features/data_upload/domain/upload_models.dart';
import 'package:apnipost_admin/features/data_upload/presentation/upload_controller.dart';
import 'package:apnipost_admin/features/data_upload/presentation/widgets/upload_drop_zone.dart';
import 'package:apnipost_admin/features/data_upload/presentation/widgets/upload_file_list.dart';
import 'package:apnipost_admin/features/data_upload/presentation/widgets/upload_progress.dart';
import 'package:apnipost_admin/features/data_upload/presentation/widgets/upload_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DataUploadPage extends ConsumerWidget {
  const DataUploadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(dataUploadControllerProvider);
    final controller = ref.read(dataUploadControllerProvider.notifier);
    final categoriesAsync = ref.watch(uploadCategoriesProvider);

    ref.listen(dataUploadControllerProvider, (previous, next) {
      final message = next.errorMessage;
      if (message != null &&
          message.isNotEmpty &&
          message != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Upload images, videos and GIFs to a category.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Unable to load categories. Please try again.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(uploadCategoriesProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (categories) => _CategorySelector(
                      categories: categories,
                      selectedName: state.selectedCategoryName,
                      enabled: !state.isUploading,
                      onChanged: controller.selectCategory,
                    ),
                  ),
                  const SizedBox(height: 16),
                  UploadDropZone(
                    enabled: state.canPickFiles,
                    onSelectFiles: controller.pickFiles,
                    helperText: state.hasCategory
                        ? null
                        : 'Select a category before uploading.',
                  ),
                  if (state.rejectedCount > 0 &&
                      state.lastRejectedReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${state.rejectedCount} file(s) skipped: ${state.lastRejectedReason}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Selected: ${state.files.length} files',
                        style: theme.textTheme.titleSmall,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: state.files.isEmpty || state.isUploading
                            ? null
                            : controller.clearAll,
                        child: const Text('Clear All'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed:
                            state.canUpload ? controller.startUpload : null,
                        child: Text(
                          state.readyCount > 0
                              ? 'Upload ${state.readyCount} Files'
                              : 'Upload Files',
                        ),
                      ),
                    ],
                  ),
                  if (state.phase == UploadPhase.uploading ||
                      state.phase == UploadPhase.completed) ...[
                    const SizedBox(height: 12),
                    UploadProgressBanner(state: state),
                  ],
                  if (state.phase == UploadPhase.completed) ...[
                    const SizedBox(height: 12),
                    UploadSummaryCard(
                      summary: state.summary,
                      showRetry: state.hasFailedFiles,
                      onRetryFailed: controller.retryFailed,
                      onUploadMore: controller.resetForMoreUploads,
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (state.files.isEmpty)
                    SizedBox(
                      height: 180,
                      child: _EmptyFiles(theme: theme),
                    )
                  else
                    UploadFileList(
                      files: state.files,
                      isLocked: state.isUploading,
                      onRemove: controller.removeFile,
                    ),
                  if (state.hasFailedFiles &&
                      state.phase == UploadPhase.completed) ...[
                    const SizedBox(height: 12),
                    _FailedDetails(files: state.files),
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

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedName,
    required this.enabled,
    required this.onChanged,
  });

  final List<ContentCategory> categories;
  final String? selectedName;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: selectedName,
        decoration: const InputDecoration(
          labelText: 'Category',
          hintText: 'Select category',
        ),
        items: [
          for (final category in categories)
            DropdownMenuItem<String>(
              value: category.name,
              child: Text(category.name),
            ),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _EmptyFiles extends StatelessWidget {
  const _EmptyFiles({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.upload_file_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No files selected',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a category and upload images, videos or GIFs.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedDetails extends StatelessWidget {
  const _FailedDetails({required this.files});

  final List<SelectedUploadFile> files;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed =
        files.where((f) => f.status == UploadItemStatus.failed).toList();

    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Failed files (${failed.length})'),
        children: [
          for (final file in failed)
            ListTile(
              dense: true,
              title: Text(file.originalFileName),
              subtitle: Text(
                [
                  _stageLabel(file.failureStage),
                  if (file.errorMessage != null) file.errorMessage!,
                ].join(' — '),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _stageLabel(UploadFailureStage? stage) {
    return switch (stage) {
      UploadFailureStage.validation => 'validation failed',
      UploadFailureStage.presign => 'presign failed',
      UploadFailureStage.r2Upload => 'R2 upload failed',
      UploadFailureStage.databaseInsert =>
        'Uploaded to storage, database record failed',
      null => 'failed',
    };
  }
}
