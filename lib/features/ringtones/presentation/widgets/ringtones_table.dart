import 'package:apnipost_admin/core/utils/date_formatters.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_rules.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/audio_play_button.dart';
import 'package:flutter/material.dart';

typedef RingtoneAction = void Function(Ringtone ringtone);

class RingtonesTable extends StatelessWidget {
  const RingtonesTable({
    super.key,
    required this.ringtones,
    required this.isMutating,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Ringtone> ringtones;
  final bool isMutating;
  final RingtoneAction onEdit;
  final RingtoneAction onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                SizedBox(width: 56),
                Expanded(flex: 3, child: Text('Title')),
                Expanded(child: Text('Category')),
                SizedBox(width: 80, child: Text('Duration')),
                Expanded(child: Text('Created')),
                SizedBox(width: 96, child: Text('Actions')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: ringtones.length,
              itemBuilder: (context, index) {
                final ringtone = ringtones[index];
                return _RingtoneRow(
                  key: ValueKey(ringtone.id),
                  ringtone: ringtone,
                  enabled: !isMutating,
                  onEdit: () => onEdit(ringtone),
                  onDelete: () => onDelete(ringtone),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RingtoneRow extends StatelessWidget {
  const _RingtoneRow({
    super.key,
    required this.ringtone,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final Ringtone ringtone;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AudioPlayButton(url: ringtone.audioUrl),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              ringtone.title,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(ringtone.category),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(RingtoneRules.formatDuration(ringtone.durationSec)),
          ),
          Expanded(
            child: Tooltip(
              message: DateFormatters.dateTime(ringtone.createdAt),
              child: Text(DateFormatters.relativeDate(ringtone.createdAt)),
            ),
          ),
          SizedBox(
            width: 96,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Edit',
                  onPressed: enabled ? onEdit : null,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: enabled ? onDelete : null,
                  icon: Icon(
                    Icons.delete_outline,
                    color: enabled ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
