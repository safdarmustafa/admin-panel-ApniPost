import 'package:flutter/foundation.dart';

/// ApniPost content category (avoids clashing with Flutter's Category).
@immutable
class ContentCategory {
  const ContentCategory({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.showOnHome,
    required this.createdAt,
    this.postCount = 0,
  });

  final String id;
  final String name;
  final int displayOrder;
  final bool showOnHome;
  final DateTime? createdAt;
  final int postCount;

  bool get hasPosts => postCount > 0;

  ContentCategory copyWith({
    String? id,
    String? name,
    int? displayOrder,
    bool? showOnHome,
    DateTime? createdAt,
    int? postCount,
  }) {
    return ContentCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      displayOrder: displayOrder ?? this.displayOrder,
      showOnHome: showOnHome ?? this.showOnHome,
      createdAt: createdAt ?? this.createdAt,
      postCount: postCount ?? this.postCount,
    );
  }

  factory ContentCategory.fromMap(
    Map<String, dynamic> map, {
    int postCount = 0,
  }) {
    return ContentCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      showOnHome: map['show_on_home'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      postCount: postCount,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'display_order': displayOrder,
      'show_on_home': showOnHome,
    };
  }
}

@immutable
class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.displayOrder,
    required this.showOnHome,
  });

  final String name;
  final int displayOrder;
  final bool showOnHome;
}
