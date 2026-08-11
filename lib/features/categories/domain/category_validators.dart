/// Pure validation helpers for category create/edit.
abstract final class CategoryValidators {
  static String normalizeName(String? raw) => (raw ?? '').trim();

  /// Returns an error message, or null when valid.
  static String? validateName(String? raw) {
    final name = normalizeName(raw);
    if (name.isEmpty) {
      return 'ContentCategory name is required.';
    }
    if (name.length > 120) {
      return 'ContentCategory name must be 120 characters or fewer.';
    }
    return null;
  }

  static String? validateDisplayOrder(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) {
      return 'Display order is required.';
    }
    final value = int.tryParse(text);
    if (value == null) {
      return 'Display order must be a whole number.';
    }
    if (value < 0) {
      return 'Display order cannot be negative.';
    }
    return null;
  }

  static int parseDisplayOrder(String? raw) {
    return int.parse((raw ?? '').trim());
  }

  /// Case-insensitive duplicate detection against existing category names.
  static bool isDuplicateName(
    String candidate, {
    required Iterable<String> existingNames,
    String? currentName,
  }) {
    final normalized = normalizeName(candidate).toLowerCase();
    final current = currentName == null
        ? null
        : normalizeName(currentName).toLowerCase();

    for (final existing in existingNames) {
      final value = existing.trim().toLowerCase();
      if (value == normalized && value != current) {
        return true;
      }
    }
    return false;
  }

  static String? validateUniqueName(
    String? raw, {
    required Iterable<String> existingNames,
    String? currentName,
  }) {
    final nameError = validateName(raw);
    if (nameError != null) return nameError;

    if (isDuplicateName(
      raw!,
      existingNames: existingNames,
      currentName: currentName,
    )) {
      return 'A category with this name already exists.';
    }
    return null;
  }

  /// Whether renaming is allowed. Disabled when posts already reference the
  /// category name (`posts.category` stores the name as text).
  static bool canRename({required int postCount}) => postCount == 0;
}
