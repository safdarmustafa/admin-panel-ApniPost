import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';

abstract class RingtoneCategoriesRepository {
  /// All categories by display order, with ringtone counts.
  Future<List<RingtoneCategory>> fetchCategories();

  Future<void> createCategory({
    required String name,
    required String? hindiName,
    required int displayOrder,
  });

  /// Renaming cascades to `ringtones.category` (ON UPDATE CASCADE).
  Future<void> updateCategory({
    required String id,
    required String name,
    required String? hindiName,
  });

  /// Persists sequential display_order values for [ordered].
  Future<void> reorderCategories(List<RingtoneCategory> ordered);

  /// Fails while ringtones still use the category (ON DELETE RESTRICT).
  Future<void> deleteCategory(String id);
}
