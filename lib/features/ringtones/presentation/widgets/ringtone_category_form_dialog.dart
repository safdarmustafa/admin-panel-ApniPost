import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_rules.dart';
import 'package:flutter/material.dart';

/// Create ([existing] null) or edit a ringtone category.
/// Returns (name, hindiName), or null when cancelled.
Future<({String name, String? hindiName})?> showRingtoneCategoryFormDialog({
  required BuildContext context,
  RingtoneCategory? existing,
  required Iterable<String> existingNames,
}) {
  return showDialog<({String name, String? hindiName})>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _RingtoneCategoryFormDialog(
      existing: existing,
      existingNames: existingNames,
    ),
  );
}

class _RingtoneCategoryFormDialog extends StatefulWidget {
  const _RingtoneCategoryFormDialog({
    required this.existing,
    required this.existingNames,
  });

  final RingtoneCategory? existing;
  final Iterable<String> existingNames;

  @override
  State<_RingtoneCategoryFormDialog> createState() =>
      _RingtoneCategoryFormDialogState();
}

class _RingtoneCategoryFormDialogState
    extends State<_RingtoneCategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hindiController;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _hindiController =
        TextEditingController(text: widget.existing?.hindiName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hindiController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final hindi = _hindiController.text.trim();
    Navigator.of(context).pop((
      name: RingtoneRules.normalizeCategoryName(_nameController.text),
      hindiName: hindi.isEmpty ? null : hindi,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ringtoneCount = widget.existing?.ringtoneCount ?? 0;
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return AlertDialog(
      title: Text(_isEditing ? 'Edit category' : 'Create category'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: RingtoneRules.maxCategoryLength,
                decoration: const InputDecoration(
                  labelText: 'English name',
                  hintText: 'e.g. Bhojpuri',
                ),
                validator: (value) => RingtoneRules.categoryNameError(
                  value ?? '',
                  existingNames: widget.existingNames,
                  currentName: widget.existing?.name,
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hindiController,
                maxLength: RingtoneRules.maxCategoryLength,
                decoration: const InputDecoration(
                  labelText: 'Hindi name (shown in the app)',
                  hintText: 'e.g. भोजपुरी',
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
              Text(
                'If the Hindi name is empty, the app shows the English name.',
                style: hintStyle,
              ),
              if (_isEditing && ringtoneCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Renaming also updates its $ringtoneCount ringtone(s).',
                  style: hintStyle,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
