import 'package:apnipost_admin/features/data_upload/domain/upload_models.dart';
import 'package:flutter/material.dart';

class UploadProgressBanner extends StatelessWidget {
  const UploadProgressBanner({
    super.key,
    required this.state,
  });

  final DataUploadState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uploaded = state.uploadedCount;
    final failed = state.failedCount;
    final total = state.files.length;
    final inFlight =
        state.files.where((f) => f.status == UploadItemStatus.uploading).length;
    final optimizing = state.files
        .where((f) => f.status == UploadItemStatus.optimizing)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (state.isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.isUploading
                    ? 'Uploading... $uploaded / $total complete'
                        '${optimizing > 0 ? ' · optimizing media' : ''}'
                        '${inFlight > 0 ? ' · $inFlight uploading' : ''}'
                    : 'Progress: $uploaded uploaded · $failed failed · $total total',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
