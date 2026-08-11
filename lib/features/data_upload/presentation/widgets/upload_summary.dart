import 'package:apnipost_admin/features/data_upload/domain/upload_models.dart';
import 'package:flutter/material.dart';

class UploadSummaryCard extends StatelessWidget {
  const UploadSummaryCard({
    super.key,
    required this.summary,
    required this.onUploadMore,
    required this.onRetryFailed,
    this.showRetry = false,
  });

  final UploadBatchSummary summary;
  final VoidCallback onUploadMore;
  final VoidCallback onRetryFailed;
  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = summary.isCompleteSuccess
        ? 'Upload Complete'
        : 'Upload Complete With Errors';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${summary.succeeded} / ${summary.total} files uploaded successfully.',
              style: theme.textTheme.bodyLarge,
            ),
            if (summary.hasFailures) ...[
              const SizedBox(height: 4),
              Text(
                '${summary.failed} failed',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Images: ${summary.imageCount}'),
            Text('GIFs: ${summary.gifCount}'),
            Text('Videos: ${summary.videoCount}'),
            const SizedBox(height: 8),
            Text('R2: ${summary.r2Uploaded} uploaded'),
            Text('Database: ${summary.dbInserted} records created'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (showRetry)
                  OutlinedButton(
                    onPressed: onRetryFailed,
                    child: const Text('Retry Failed'),
                  ),
                FilledButton(
                  onPressed: onUploadMore,
                  child: const Text('Upload More'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
