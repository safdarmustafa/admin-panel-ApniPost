import 'package:apnipost_admin/features/categories/domain/category_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoryValidators.validateName', () {
    test('rejects empty and whitespace names', () {
      expect(CategoryValidators.validateName(null), isNotNull);
      expect(CategoryValidators.validateName(''), isNotNull);
      expect(CategoryValidators.validateName('   '), isNotNull);
    });

    test('accepts trimmed non-empty names', () {
      expect(CategoryValidators.validateName('Islamic'), isNull);
      expect(CategoryValidators.validateName('  Ramadan  '), isNull);
    });
  });

  group('CategoryValidators.duplicate protection', () {
    test('detects case-insensitive duplicates', () {
      expect(
        CategoryValidators.isDuplicateName(
          'islamic',
          existingNames: const ['Islamic', 'Ramadan'],
        ),
        isTrue,
      );
    });

    test('allows keeping the same name when editing', () {
      expect(
        CategoryValidators.isDuplicateName(
          'Islamic',
          existingNames: const ['Islamic', 'Ramadan'],
          currentName: 'Islamic',
        ),
        isFalse,
      );
    });

    test('validateUniqueName returns duplicate message', () {
      final error = CategoryValidators.validateUniqueName(
        'RAMADAN',
        existingNames: const ['Islamic', 'Ramadan'],
      );
      expect(error, 'A category with this name already exists.');
    });
  });

  group('CategoryValidators.rename protection', () {
    test('rename allowed only when postCount is zero', () {
      expect(CategoryValidators.canRename(postCount: 0), isTrue);
      expect(CategoryValidators.canRename(postCount: 3), isFalse);
    });
  });

  group('CategoryValidators.display order', () {
    test('requires non-negative integer', () {
      expect(CategoryValidators.validateDisplayOrder(''), isNotNull);
      expect(CategoryValidators.validateDisplayOrder('abc'), isNotNull);
      expect(CategoryValidators.validateDisplayOrder('-1'), isNotNull);
      expect(CategoryValidators.validateDisplayOrder('2'), isNull);
      expect(CategoryValidators.parseDisplayOrder('12'), 12);
    });
  });
}
