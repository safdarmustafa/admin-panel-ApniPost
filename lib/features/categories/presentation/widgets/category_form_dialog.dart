import 'package:apnipost_admin/features/categories/domain/category.dart';
import 'package:apnipost_admin/features/categories/domain/category_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<CategoryDraft?> showCategoryFormDialog({
  required BuildContext context,
  ContentCategory? existing,
  required Iterable<String> existingNames,
  int? suggestedDisplayOrder,
}) {
  return showDialog<CategoryDraft>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CategoryFormDialog(
      existing: existing,
      existingNames: existingNames,
      suggestedDisplayOrder: suggestedDisplayOrder ?? 0,
    ),
  );
}

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key,
    this.existing,
    required this.existingNames,
    required this.suggestedDisplayOrder,
  });

  final ContentCategory? existing;
  final Iterable<String> existingNames;
  final int suggestedDisplayOrder;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _orderController;
  late bool _showOnHome;
  late final bool _renameLocked;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _renameLocked = existing != null &&
        !CategoryValidators.canRename(postCount: existing.postCount);
    _nameController = TextEditingController(text: existing?.name ?? '');
    _orderController = TextEditingController(
      text: '${existing?.displayOrder ?? widget.suggestedDisplayOrder}',
    );
    _showOnHome = existing?.showOnHome ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _renameLocked
        ? widget.existing!.name
        : CategoryValidators.normalizeName(_nameController.text);

    Navigator.of(context).pop(
      CategoryDraft(
        name: name,
        displayOrder: CategoryValidators.parseDisplayOrder(_orderController.text),
        showOnHome: _showOnHome,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit category' : 'Create category'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_renameLocked,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Islamic',
                ),
                validator: (value) => CategoryValidators.validateUniqueName(
                  value,
                  existingNames: widget.existingNames,
                  currentName: widget.existing?.name,
                ),
              ),
              if (_renameLocked) ...[
                const SizedBox(height: 8),
                Text(
                  'This category contains existing posts. Renaming is '
                  'disabled to protect existing content.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _orderController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Display Order',
                  hintText: '0',
                ),
                validator: CategoryValidators.validateDisplayOrder,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show on Home'),
                subtitle: const Text(
                  'Controls whether this category appears on the home screen.',
                ),
                value: _showOnHome,
                onChanged: (value) => setState(() => _showOnHome = value),
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
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
