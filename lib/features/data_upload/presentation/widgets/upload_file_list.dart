import 'package:apnipost_admin/features/data_upload/domain/upload_models.dart';
import 'package:flutter/material.dart';

class UploadFileList extends StatelessWidget {
  const UploadFileList({
    super.key,
    required this.files,
    required this.isLocked,
    required this.onRemove,
  });

  final List<SelectedUploadFile> files;
  final bool isLocked;
  final void Function(String localId) onRemove;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            child: const Row(
              children: [
                SizedBox(width: 56, child: Text('Preview')),
                Expanded(flex: 3, child: Text('File name')),
                Expanded(child: Text('Type')),
                Expanded(child: Text('Size')),
                Expanded(flex: 2, child: Text('Status')),
                SizedBox(width: 48, child: Text('')),
              ],
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < files.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: _Preview(file: files[index]),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      files[index].originalFileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Text(_typeLabel(files[index])),
                  ),
                  Expanded(
                    child: Text(_sizeLabel(files[index])),
                  ),
                  Expanded(
                    flex: 2,
                    child: _StatusCell(file: files[index]),
                  ),
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      tooltip: 'Remove',
                      onPressed: isLocked ||
                              files[index].status ==
                                  UploadItemStatus.uploading ||
                              files[index].status ==
                                  UploadItemStatus.optimizing
                          ? null
                          : () => onRemove(files[index].localId),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _sizeLabel(SelectedUploadFile file) {
    final original = file.originalSizeBytes;
    if (original == null) return _formatBytes(file.sizeBytes);
    return '${_formatBytes(original)} → ${_formatBytes(file.sizeBytes)}';
  }

  String _typeLabel(SelectedUploadFile file) {
    final media = file.mediaType;
    if (media == null) return file.contentType;
    return media.name;
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.file});

  final SelectedUploadFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (file.isImagePreviewable) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          file.bytes,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.broken_image_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Icon(
      Icons.movie_outlined,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.file});

  final SelectedUploadFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (file.status) {
      case UploadItemStatus.ready:
        return Text(
          'Ready',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      case UploadItemStatus.optimizing:
        final percent = ((file.optimizeProgress ?? 0) * 100).round();
        return Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Optimizing $percent%',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        );
      case UploadItemStatus.uploading:
        return Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text(
              'Uploading...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        );
      case UploadItemStatus.uploaded:
        return Text(
          'Uploaded ✓',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        );
      case UploadItemStatus.failed:
        return Tooltip(
          message: _failureTooltip(file),
          child: Text(
            'Failed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }

  String _failureTooltip(SelectedUploadFile file) {
    final stage = switch (file.failureStage) {
      UploadFailureStage.validation => 'Validation failed',
      UploadFailureStage.optimization => 'Compression failed',
      UploadFailureStage.presign => 'Presign failed',
      UploadFailureStage.r2Upload => 'R2 upload failed',
      UploadFailureStage.databaseInsert =>
        'Uploaded to storage, database record failed',
      null => 'Failed',
    };
    final message = file.errorMessage;
    if (message == null || message.isEmpty) return stage;
    return '$stage — $message';
  }
}
