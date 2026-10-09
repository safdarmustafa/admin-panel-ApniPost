import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/data_upload/data/browser_file_picker.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_rules.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/audio_play_button.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/category_dropdown.dart';
import 'package:apnipost_admin/shared/web/web_audio.dart';
import 'package:flutter/material.dart';

/// Bulk (or single) ringtone upload. Each picked file becomes an editable
/// row; [upload] saves one draft and throws [AppFailure] on error.
///
/// Returns how many ringtones were uploaded.
Future<int> showRingtoneUploadDialog({
  required BuildContext context,
  required List<RingtoneCategory> categories,
  required Future<Ringtone> Function(RingtoneDraft draft) upload,
}) async {
  final uploaded = await showDialog<int>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _RingtoneUploadDialog(
      categories: categories,
      upload: upload,
    ),
  );
  return uploaded ?? 0;
}

enum _RowStatus { probing, ready, tooLong, uploading, done, failed }

class _UploadRow {
  _UploadRow({
    required this.file,
    required this.contentType,
    required this.blobUrl,
  }) : title = TextEditingController(
          text: RingtoneRules.titleFromFileName(file.name),
        );

  final BrowserPickedFile file;
  final String contentType;

  /// Local `blob:` URL for preview and the duration probe.
  final String blobUrl;
  final TextEditingController title;

  /// Null follows the batch category.
  String? categoryOverride;
  int? durationSec;
  _RowStatus status = _RowStatus.probing;
  String? message;

  bool get isLocked =>
      status == _RowStatus.uploading || status == _RowStatus.done;

  bool get isPending =>
      status == _RowStatus.ready || status == _RowStatus.failed;
}

class _RingtoneUploadDialog extends StatefulWidget {
  const _RingtoneUploadDialog({
    required this.categories,
    required this.upload,
  });

  final List<RingtoneCategory> categories;
  final Future<Ringtone> Function(RingtoneDraft draft) upload;

  @override
  State<_RingtoneUploadDialog> createState() => _RingtoneUploadDialogState();
}

class _RingtoneUploadDialogState extends State<_RingtoneUploadDialog> {
  final List<_UploadRow> _rows = [];
  final List<String> _unsupported = [];
  String? _batchCategory;
  bool _uploading = false;
  int _uploadedCount = 0;

  @override
  void dispose() {
    AudioPreviewPlayer.instance.stop();
    for (final row in _rows) {
      revokeBlobUrl(row.blobUrl);
      row.title.dispose();
    }
    super.dispose();
  }

  String? _categoryFor(_UploadRow row) => row.categoryOverride ?? _batchCategory;

  int get _pendingCount => _rows.where((row) => row.isPending).length;

  /// Must run straight from the button tap (browser user-gesture rule).
  Future<void> _pickFiles() async {
    final List<BrowserPickedFile> picked;
    try {
      picked = await BrowserFilePicker.pickMultiple(
        accept: RingtoneRules.pickerAccept,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file picker.')),
      );
      return;
    }
    if (!mounted || picked.isEmpty) return;

    final added = <_UploadRow>[];
    setState(() {
      _unsupported.clear();
      for (final file in picked) {
        final contentType =
            RingtoneRules.contentTypeFor(file.name, file.mimeType);
        if (contentType == null) {
          _unsupported.add(file.name);
          continue;
        }
        final row = _UploadRow(
          file: file,
          contentType: contentType,
          blobUrl: createBlobUrl(file.bytes, contentType),
        );
        added.add(row);
        _rows.add(row);
      }
    });

    await Future.wait(added.map(_probe));
  }

  Future<void> _probe(_UploadRow row) async {
    final seconds = await probeAudioDuration(row.blobUrl);
    if (!mounted || !_rows.contains(row)) return;
    setState(() {
      if (seconds == null) {
        row
          ..status = _RowStatus.tooLong
          ..message = 'Could not read this file. Is it a valid audio file?';
        return;
      }
      final rounded = RingtoneRules.roundDuration(seconds);
      final error = RingtoneRules.durationError(rounded);
      row
        ..durationSec = rounded
        ..status = error == null ? _RowStatus.ready : _RowStatus.tooLong
        ..message = error;
    });
  }

  void _removeRow(_UploadRow row) {
    AudioPreviewPlayer.instance.stopIfPlaying(row.blobUrl);
    revokeBlobUrl(row.blobUrl);
    setState(() => _rows.remove(row));
    row.title.dispose();
  }

  /// Null when [row] can be uploaded; otherwise why not.
  String? _blockReason(_UploadRow row) {
    final titleError = RingtoneRules.titleError(row.title.text);
    if (titleError != null) return titleError;
    if (_categoryFor(row) == null) return 'Choose a category.';
    final duration = row.durationSec;
    if (duration == null) return 'Duration not detected yet.';
    return RingtoneRules.durationError(duration);
  }

  Future<void> _uploadRows(List<_UploadRow> rows) async {
    setState(() => _uploading = true);
    for (final row in rows) {
      if (!mounted) return;
      final reason = _blockReason(row);
      if (reason != null) {
        setState(() {
          row
            ..status = _RowStatus.failed
            ..message = reason;
        });
        continue;
      }

      setState(() {
        row
          ..status = _RowStatus.uploading
          ..message = null;
      });
      try {
        await widget.upload(
          RingtoneDraft(
            title: row.title.text.trim(),
            category: _categoryFor(row)!,
            contentType: row.contentType,
            durationSec: row.durationSec!,
            bytes: row.file.bytes,
          ),
        );
        if (!mounted) return;
        setState(() {
          row.status = _RowStatus.done;
          _uploadedCount++;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          row
            ..status = _RowStatus.failed
            ..message = error is AppFailure
                ? error.message
                : 'Upload failed. Please try again.';
        });
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  void _close() => Navigator.of(context).pop(_uploadedCount);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final pending = _pendingCount;
    final probing = _rows.any((row) => row.status == _RowStatus.probing);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1000,
          maxHeight: size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upload ringtones',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _uploading ? null : _close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'MP3, M4A or OGG, up to 60 seconds. Titles are filled in from '
                'the file names; edit any that look wrong.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: CategoryDropdown(
                      categories: widget.categories,
                      value: _batchCategory,
                      label: 'Category for all files',
                      enabled: !_uploading,
                      onChanged: (name) =>
                          setState(() => _batchCategory = name),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FilledButton.tonalIcon(
                      onPressed: _uploading ? null : _pickFiles,
                      icon: const Icon(Icons.library_music_outlined),
                      label: Text(_rows.isEmpty ? 'Choose files' : 'Add files'),
                    ),
                  ),
                ],
              ),
              if (_unsupported.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Skipped (not MP3/M4A/OGG): ${_unsupported.join(', ')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Flexible(
                child: _rows.isEmpty
                    ? _EmptyPicker(onPick: _pickFiles)
                    : Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _rows.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            return _UploadRowTile(
                              key: ObjectKey(row),
                              row: row,
                              categories: widget.categories,
                              category: _categoryFor(row),
                              busy: _uploading,
                              onTitleChanged: () => setState(() {}),
                              onCategoryChanged: (name) => setState(() {
                                row.categoryOverride =
                                    name == _batchCategory ? null : name;
                              }),
                              onRemove: () => _removeRow(row),
                              onRetry: () => _uploadRows([row]),
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _summary(probing: probing),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _uploading ? null : _close,
                    child: Text(_uploadedCount > 0 ? 'Done' : 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _uploading || probing || pending == 0
                        ? null
                        : () => _uploadRows(
                              _rows.where((row) => row.isPending).toList(),
                            ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      pending <= 1
                          ? 'Upload'
                          : 'Upload $pending ringtones',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _summary({required bool probing}) {
    if (_rows.isEmpty) return 'No files selected.';
    final tooLong =
        _rows.where((row) => row.status == _RowStatus.tooLong).length;
    final failed = _rows.where((row) => row.status == _RowStatus.failed).length;
    final parts = <String>[
      '${_rows.length} file${_rows.length == 1 ? '' : 's'}',
      if (_uploadedCount > 0) '$_uploadedCount uploaded',
      if (failed > 0) '$failed failed',
      if (tooLong > 0) '$tooLong skipped',
      if (probing) 'reading durations…',
    ];
    return parts.join(' · ');
  }
}

class _EmptyPicker extends StatelessWidget {
  const _EmptyPicker({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text('Choose one or more ringtone files',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Best: 20–30 seconds, 64–128 kbps (about 200–500 KB).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadRowTile extends StatelessWidget {
  const _UploadRowTile({
    super.key,
    required this.row,
    required this.categories,
    required this.category,
    required this.busy,
    required this.onTitleChanged,
    required this.onCategoryChanged,
    required this.onRemove,
    required this.onRetry,
  });

  final _UploadRow row;
  final List<RingtoneCategory> categories;
  final String? category;
  final bool busy;
  final VoidCallback onTitleChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editable = !busy && !row.isLocked;
    final skipped = row.status == _RowStatus.tooLong;
    final sizeWarning = RingtoneRules.sizeWarning(row.file.bytes.lengthInBytes);
    final duration = row.durationSec;

    final details = [
      row.file.name,
      RingtoneRules.formatBytes(row.file.bytes.lengthInBytes),
      if (duration != null) RingtoneRules.formatDuration(duration),
    ].join(' · ');

    return Container(
      color: skipped
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.35)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AudioPlayButton(url: row.blobUrl),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: row.title,
                  enabled: editable && !skipped,
                  maxLength: RingtoneRules.maxTitleLength,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    isDense: true,
                    counterText: '',
                  ),
                  onChanged: (_) => onTitleChanged(),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (row.message != null)
                  Text(
                    row.message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                else if (sizeWarning != null && !row.isLocked)
                  Text(
                    sizeWarning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 200,
            child: CategoryDropdown(
              categories: categories,
              value: category,
              label: null,
              hint: 'Category',
              dense: true,
              enabled: editable && !skipped,
              onChanged: onCategoryChanged,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _statusAction(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusAction(ThemeData theme) {
    switch (row.status) {
      case _RowStatus.probing:
      case _RowStatus.uploading:
        return const Padding(
          padding: EdgeInsets.all(10),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case _RowStatus.done:
        return Tooltip(
          message: 'Uploaded',
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ),
        );
      case _RowStatus.failed:
        return busy
            ? const SizedBox.shrink()
            : PopupMenuButton<String>(
                tooltip: 'Retry or remove',
                icon: Icon(Icons.error_outline, color: theme.colorScheme.error),
                onSelected: (action) =>
                    action == 'retry' ? onRetry() : onRemove(),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'retry', child: Text('Retry')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              );
      case _RowStatus.ready:
      case _RowStatus.tooLong:
        return IconButton(
          tooltip: 'Remove',
          onPressed: busy ? null : onRemove,
          icon: const Icon(Icons.close),
        );
    }
  }
}
