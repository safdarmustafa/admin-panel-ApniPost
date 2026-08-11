import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/categories/domain/categories_repository.dart';
import 'package:apnipost_admin/features/categories/domain/category.dart';
import 'package:apnipost_admin/features/categories/domain/category_validators.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory repository for category mutation/business-rule tests.
class FakeCategoriesRepository implements CategoriesRepository {
  FakeCategoriesRepository(this.items);

  final List<ContentCategory> items;
  bool denyWrites = false;
  Object? nextError;

  @override
  Future<List<ContentCategory>> fetchCategories() async {
    _throwIfNeeded();
    final sorted = [...items]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return sorted;
  }

  @override
  Future<bool> isNameTaken(String name, {String? excludingId}) async {
    final normalized = name.trim().toLowerCase();
    return items.any(
      (item) =>
          item.id != excludingId &&
          item.name.trim().toLowerCase() == normalized,
    );
  }

  @override
  Future<ContentCategory> createCategory({
    required String name,
    required int displayOrder,
    required bool showOnHome,
  }) async {
    _throwIfNeeded();
    if (denyWrites) {
      throw const AppFailure('You are not authorized to change categories.');
    }
    if (await isNameTaken(name)) {
      throw const AppFailure('A category with this name already exists.');
    }
    final created = ContentCategory(
      id: 'id-${items.length + 1}',
      name: name.trim(),
      displayOrder: displayOrder,
      showOnHome: showOnHome,
      createdAt: DateTime.utc(2026, 8, 11),
      postCount: 0,
    );
    items.add(created);
    return created;
  }

  @override
  Future<ContentCategory> updateCategory({
    required ContentCategory category,
    required String name,
    required int displayOrder,
    required bool showOnHome,
  }) async {
    _throwIfNeeded();
    if (denyWrites) {
      throw const AppFailure('You are not authorized to change categories.');
    }

    final normalized = name.trim();
    final renaming =
        normalized.toLowerCase() != category.name.toLowerCase();
    if (renaming && category.hasPosts) {
      throw const AppFailure(
        'This category contains existing posts. Renaming is disabled to '
        'protect existing content.',
      );
    }

    final index = items.indexWhere((item) => item.id == category.id);
    final updated = category.copyWith(
      name: normalized,
      displayOrder: displayOrder,
      showOnHome: showOnHome,
    );
    items[index] = updated;
    return updated;
  }

  @override
  Future<void> setShowOnHome({
    required String id,
    required bool showOnHome,
  }) async {
    _throwIfNeeded();
    if (denyWrites) {
      throw const AppFailure('You are not authorized to change categories.');
    }
    final index = items.indexWhere((item) => item.id == id);
    items[index] = items[index].copyWith(showOnHome: showOnHome);
  }

  @override
  Future<void> reorderCategories(List<ContentCategory> ordered) async {
    _throwIfNeeded();
    if (denyWrites) {
      throw const AppFailure('You are not authorized to change categories.');
    }
    items
      ..clear()
      ..addAll([
        for (var i = 0; i < ordered.length; i++)
          ordered[i].copyWith(displayOrder: i),
      ]);
  }

  @override
  Future<int> countPostsForCategory(String categoryName) async {
    _throwIfNeeded();
    return items
        .firstWhere(
          (item) => item.name == categoryName,
          orElse: () => ContentCategory(
            id: 'missing',
            name: categoryName,
            displayOrder: 0,
            showOnHome: false,
            createdAt: null,
          ),
        )
        .postCount;
  }

  @override
  Future<void> deleteCategory(ContentCategory category) async {
    _throwIfNeeded();
    if (denyWrites) {
      throw const AppFailure('You are not authorized to change categories.');
    }
    final count = await countPostsForCategory(category.name);
    if (count > 0) {
      throw AppFailure(
        'This category contains $count posts and cannot be deleted.',
      );
    }
    items.removeWhere((item) => item.id == category.id);
  }

  void _throwIfNeeded() {
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
  }
}

void main() {
  ContentCategory category({
    required String id,
    required String name,
    int order = 0,
    bool showOnHome = false,
    int postCount = 0,
  }) {
    return ContentCategory(
      id: id,
      name: name,
      displayOrder: order,
      showOnHome: showOnHome,
      createdAt: DateTime.utc(2026, 7, 31),
      postCount: postCount,
    );
  }

  test('loading returns categories sorted by display_order', () async {
    final repo = FakeCategoriesRepository([
      category(id: '2', name: 'B', order: 2),
      category(id: '1', name: 'A', order: 1),
    ]);

    final result = await repo.fetchCategories();
    expect(result.map((c) => c.name), ['A', 'B']);
  });

  test('empty state has zero categories', () async {
    final repo = FakeCategoriesRepository([]);
    final result = await repo.fetchCategories();
    expect(result, isEmpty);
  });

  test('create validation rejects empty names before repository call', () {
    expect(CategoryValidators.validateName('  '), isNotNull);
  });

  test('creation succeeds for unique names', () async {
    final repo = FakeCategoriesRepository([]);
    final created = await repo.createCategory(
      name: 'Quotes',
      displayOrder: 0,
      showOnHome: true,
    );
    expect(created.name, 'Quotes');
    expect(created.showOnHome, isTrue);
    expect(await repo.fetchCategories(), hasLength(1));
  });

  test('duplicate protection rejects same name ignoring case', () async {
    final repo = FakeCategoriesRepository([
      category(id: '1', name: 'Islamic'),
    ]);

    expect(
      () => repo.createCategory(
        name: 'islamic',
        displayOrder: 1,
        showOnHome: false,
      ),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        ),
      ),
    );
  });

  test('editing updates show_on_home and order', () async {
    final existing = category(id: '1', name: 'Islamic', order: 1);
    final repo = FakeCategoriesRepository([existing]);

    final updated = await repo.updateCategory(
      category: existing,
      name: 'Islamic',
      displayOrder: 5,
      showOnHome: true,
    );

    expect(updated.displayOrder, 5);
    expect(updated.showOnHome, isTrue);
  });

  test('renaming is blocked when posts exist', () async {
    final existing = category(
      id: '1',
      name: 'Islamic',
      postCount: 12,
    );
    final repo = FakeCategoriesRepository([existing]);

    expect(
      () => repo.updateCategory(
        category: existing,
        name: 'Faith',
        displayOrder: 1,
        showOnHome: false,
      ),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('Renaming is disabled'),
        ),
      ),
    );
  });

  test('renaming is allowed when category has zero posts', () async {
    final existing = category(id: '1', name: 'Islamic', postCount: 0);
    final repo = FakeCategoriesRepository([existing]);

    final updated = await repo.updateCategory(
      category: existing,
      name: 'Faith',
      displayOrder: 1,
      showOnHome: false,
    );

    expect(updated.name, 'Faith');
  });

  test('show_on_home toggle updates value', () async {
    final existing = category(id: '1', name: 'Islamic', showOnHome: false);
    final repo = FakeCategoriesRepository([existing]);

    await repo.setShowOnHome(id: '1', showOnHome: true);
    expect((await repo.fetchCategories()).single.showOnHome, isTrue);
  });

  test('ordering persists new display_order values', () async {
    final repo = FakeCategoriesRepository([
      category(id: 'a', name: 'A', order: 0),
      category(id: 'b', name: 'B', order: 1),
      category(id: 'c', name: 'C', order: 2),
    ]);

    await repo.reorderCategories([
      category(id: 'c', name: 'C'),
      category(id: 'a', name: 'A'),
      category(id: 'b', name: 'B'),
    ]);

    final result = await repo.fetchCategories();
    expect(result.map((c) => c.name).toList(), ['C', 'A', 'B']);
    expect(result.map((c) => c.displayOrder).toList(), [0, 1, 2]);
  });

  test('delete with existing posts is blocked', () async {
    final existing = category(id: '1', name: 'Islamic', postCount: 5);
    final repo = FakeCategoriesRepository([existing]);

    expect(
      () => repo.deleteCategory(existing),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'This category contains 5 posts and cannot be deleted.',
        ),
      ),
    );
    expect(await repo.fetchCategories(), hasLength(1));
  });

  test('delete empty category succeeds', () async {
    final existing = category(id: '1', name: 'Islamic', postCount: 0);
    final repo = FakeCategoriesRepository([existing]);

    await repo.deleteCategory(existing);
    expect(await repo.fetchCategories(), isEmpty);
  });

  test('error handling surfaces repository failures', () async {
    final repo = FakeCategoriesRepository([])
      ..nextError = const AppFailure('Unable to load categories. Please try again.');

    expect(
      () => repo.fetchCategories(),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('Unable to load categories'),
        ),
      ),
    );
  });

  test('unauthorized writes are rejected', () async {
    final repo = FakeCategoriesRepository([])..denyWrites = true;

    expect(
      () => repo.createCategory(
        name: 'New',
        displayOrder: 0,
        showOnHome: false,
      ),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('not authorized'),
        ),
      ),
    );
  });
}
