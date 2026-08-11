import 'package:apnipost_admin/features/categories/domain/category.dart';

abstract class CategoriesRepository {
  /// Loads all categories sorted by display_order ascending, with post counts.
  Future<List<ContentCategory>> fetchCategories();

  /// Exact case-insensitive duplicate check against the database.
  Future<bool> isNameTaken(String name, {String? excludingId});

  Future<ContentCategory> createCategory({
    required String name,
    required int displayOrder,
    required bool showOnHome,
  });

  Future<ContentCategory> updateCategory({
    required ContentCategory category,
    required String name,
    required int displayOrder,
    required bool showOnHome,
  });

  Future<void> setShowOnHome({
    required String id,
    required bool showOnHome,
  });

  /// Persists a full ordered list by rewriting display_order (0..n-1 or given).
  Future<void> reorderCategories(List<ContentCategory> ordered);

  /// Returns the number of posts with `posts.category == categoryName`.
  Future<int> countPostsForCategory(String categoryName);

  Future<void> deleteCategory(ContentCategory category);
}
