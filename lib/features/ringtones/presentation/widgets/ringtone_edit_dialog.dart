import 'package:apnipost_admin/features/ringtones/domain/ringtone.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_rules.dart';
import 'package:apnipost_admin/features/ringtones/presentation/widgets/category_dropdown.dart';
import 'package:flutter/material.dart';

/// Returns the new (title, category), or null when cancelled.
Future<({String title, String category})?> showRingtoneEditDialog({
  required BuildContext context,
  required Ringtone ringtone,
  required List<RingtoneCategory> categories,
}) {
  return showDialog<({String title, String category})>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _RingtoneEditDialog(
      ringtone: ringtone,
      categories: categories,
    ),
  );
}

class _RingtoneEditDialog extends StatefulWidget {
  const _RingtoneEditDialog({
    required this.ringtone,
    required this.categories,
  });

  final Ringtone ringtone;
  final List<RingtoneCategory> categories;

  @override
  State<_RingtoneEditDialog> createState() => _RingtoneEditDialogState();
}

class _RingtoneEditDialogState extends State<_RingtoneEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late String _category;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.ringtone.title);
    _category = widget.ringtone.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      title: _titleController.text.trim(),
      category: _category,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryChanged = _category != widget.ringtone.category;

    return AlertDialog(
      title: const Text('Edit ringtone'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                autofocus: true,
                maxLength: RingtoneRules.maxTitleLength,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => RingtoneRules.titleError(value ?? ''),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              CategoryDropdown(
                categories: widget.categories,
                value: _category,
                onChanged: (name) => setState(() => _category = name),
              ),
              if (categoryChanged) ...[
                const SizedBox(height: 8),
                Text(
                  'The audio file stays in its current storage folder; the app '
                  'only uses its URL.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'The title inside the file (shown in phone sound settings) is '
                'only set at upload and does not change here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
