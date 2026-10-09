import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:flutter/material.dart';

/// Category picker backed by `ringtone_categories`. New categories are
/// created on the Ringtone Categories page, not here.
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.label = 'Category',
    this.hint = 'Choose a category',
    this.enabled = true,
    this.dense = false,
  });

  final List<RingtoneCategory> categories;

  /// Selected category name.
  final String? value;
  final ValueChanged<String> onChanged;
  final String? label;
  final String hint;
  final bool enabled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final known = categories.any((c) => c.name == value);
    return DropdownButtonFormField<String>(
      // Rebuild when value changes from outside (e.g. batch category).
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      isDense: dense,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: dense,
      ),
      items: [
        for (final category in categories)
          DropdownMenuItem(
            value: category.name,
            child: Text(category.label, overflow: TextOverflow.ellipsis),
          ),
        // Keep a stale selection visible instead of crashing the field.
        if (value != null && !known)
          DropdownMenuItem(value: value, child: Text(value!)),
      ],
      onChanged: enabled
          ? (selected) {
              if (selected != null) onChanged(selected);
            }
          : null,
    );
  }
}
