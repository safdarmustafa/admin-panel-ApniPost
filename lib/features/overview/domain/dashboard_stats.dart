import 'package:flutter/foundation.dart';

/// Aggregates returned by `public.admin_dashboard_stats()`.
@immutable
class DashboardStats {
  const DashboardStats({
    required this.postsTotal,
    required this.postsImages,
    required this.postsVideos,
    required this.postsLast7d,
    required this.postsPrev7d,
    required this.postsByDay,
    required this.categories,
    required this.orphanCategories,
    required this.usersTotal,
    required this.usersLast7d,
    required this.usersPrev7d,
    required this.usersByDay,
    required this.subsActive,
    required this.subsPending,
    required this.subsRenewing7d,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    List<Map<String, dynamic>> list(String key) =>
        ((json[key] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);

    return DashboardStats(
      postsTotal: n('posts_total'),
      postsImages: n('posts_images'),
      postsVideos: n('posts_videos'),
      postsLast7d: n('posts_last_7d'),
      postsPrev7d: n('posts_prev_7d'),
      postsByDay: list('posts_by_day').map(DayCount.fromJson).toList(),
      categories: list('categories').map(CategoryStat.fromJson).toList(),
      orphanCategories:
          list('orphan_categories').map(OrphanCategory.fromJson).toList(),
      usersTotal: n('users_total'),
      usersLast7d: n('users_last_7d'),
      usersPrev7d: n('users_prev_7d'),
      usersByDay: list('users_by_day').map(DayCount.fromJson).toList(),
      subsActive: n('subs_active'),
      subsPending: n('subs_pending'),
      subsRenewing7d: n('subs_renewing_7d'),
    );
  }

  final int postsTotal;
  final int postsImages;
  final int postsVideos;
  final int postsLast7d;
  final int postsPrev7d;
  final List<DayCount> postsByDay;
  final List<CategoryStat> categories;
  final List<OrphanCategory> orphanCategories;
  final int usersTotal;
  final int usersLast7d;
  final int usersPrev7d;
  final List<DayCount> usersByDay;
  final int subsActive;

  /// Started checkout but never activated.
  final int subsPending;
  final int subsRenewing7d;

  int get hiddenPosts =>
      orphanCategories.fold(0, (sum, orphan) => sum + orphan.count);

  /// Shown on the app's home screen but with no posts at all.
  List<CategoryStat> get emptyHomeCategories => [
        for (final category in categories)
          if (category.showOnHome && category.count == 0) category,
      ];

  /// Shown on home with posts, but nothing new for [staleAfter].
  List<CategoryStat> staleHomeCategories({
    Duration staleAfter = const Duration(days: 21),
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(staleAfter);
    return [
      for (final category in categories)
        if (category.showOnHome &&
            category.lastUpload != null &&
            category.lastUpload!.isBefore(cutoff))
          category,
    ]..sort((a, b) => a.lastUpload!.compareTo(b.lastUpload!));
  }
}

@immutable
class DayCount {
  const DayCount({required this.day, required this.count});

  factory DayCount.fromJson(Map<String, dynamic> json) => DayCount(
        day: DateTime.parse(json['day'].toString()),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );

  final DateTime day;
  final int count;
}

@immutable
class CategoryStat {
  const CategoryStat({
    required this.name,
    required this.showOnHome,
    required this.count,
    required this.lastUpload,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) => CategoryStat(
        name: json['name'].toString(),
        showOnHome: json['show_on_home'] == true,
        count: (json['count'] as num?)?.toInt() ?? 0,
        lastUpload: DateTime.tryParse(json['last_upload']?.toString() ?? ''),
      );

  final String name;
  final bool showOnHome;
  final int count;
  final DateTime? lastUpload;
}

@immutable
class OrphanCategory {
  const OrphanCategory({required this.name, required this.count});

  factory OrphanCategory.fromJson(Map<String, dynamic> json) => OrphanCategory(
        name: json['name'].toString(),
        count: (json['count'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final int count;
}
