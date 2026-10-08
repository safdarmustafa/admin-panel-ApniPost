import 'package:apnipost_admin/core/utils/date_formatters.dart';
import 'package:apnipost_admin/features/overview/domain/dashboard_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 8, 12);

  DashboardStats stats() => DashboardStats.fromJson({
        'posts_total': 480,
        'posts_images': 422,
        'posts_videos': 58,
        'posts_last_7d': 1,
        'posts_prev_7d': 40,
        'posts_by_day': [
          {'day': '2026-10-07', 'count': 0},
          {'day': '2026-10-08', 'count': 1},
        ],
        'categories': [
          {
            'name': 'Love',
            'show_on_home': true,
            'count': 37,
            'last_upload': '2026-10-01T10:00:00+00:00',
          },
          {
            'name': 'Updesh',
            'show_on_home': true,
            'count': 32,
            'last_upload': '2026-08-15T17:56:38+00:00',
          },
          {'name': 'New', 'show_on_home': true, 'count': 0, 'last_upload': null},
          {'name': 'Sad', 'show_on_home': false, 'count': 0, 'last_upload': null},
        ],
        'orphan_categories': [
          {'name': 'Bhagwan', 'count': 107},
          {'name': 'Islamic', 'count': 4},
        ],
        'users_total': 1463,
        'users_by_day': <Object>[],
        'subs_active': 215,
        'subs_pending': 432,
        'subs_renewing_7d': 2,
      });

  test('parses totals and lists', () {
    final s = stats();
    expect(s.postsTotal, 480);
    expect(s.postsByDay.last.count, 1);
    expect(s.categories, hasLength(4));
    expect(s.usersLast7d, 0, reason: 'missing keys default to 0');
    expect(s.subsRenewing7d, 2);
  });

  test('hidden posts sum orphan categories', () {
    expect(stats().hiddenPosts, 111);
  });

  test('empty home categories ignore categories hidden from home', () {
    expect(stats().emptyHomeCategories.map((c) => c.name), ['New']);
  });

  test('stale home categories are those without uploads in 3 weeks', () {
    expect(
      stats().staleHomeCategories(now: now).map((c) => c.name),
      ['Updesh'],
    );
  });

  test('relativeDate buckets', () {
    final ref = DateTime(2026, 10, 8, 18);
    expect(DateFormatters.relativeDate(DateTime(2026, 10, 8, 1), now: ref),
        'Today');
    expect(DateFormatters.relativeDate(DateTime(2026, 10, 7, 23), now: ref),
        'Yesterday');
    expect(DateFormatters.relativeDate(DateTime(2026, 10, 1), now: ref),
        '7 days ago');
    expect(DateFormatters.relativeDate(DateTime(2026, 8, 15), now: ref),
        'Aug 15, 2026');
    expect(DateFormatters.relativeDate(null), '—');
  });
}
