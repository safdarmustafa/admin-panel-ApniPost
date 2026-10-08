import 'package:apnipost_admin/core/constants/app_routes.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/date_formatters.dart';
import 'package:apnipost_admin/features/overview/data/dashboard_repository.dart';
import 'package:apnipost_admin/features/overview/domain/dashboard_stats.dart';
import 'package:apnipost_admin/features/overview/presentation/widgets/daily_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

final dashboardStatsProvider =
    FutureProvider.autoDispose<DashboardStats>((ref) {
  return ref.watch(dashboardRepositoryProvider).fetchStats();
});

class OverviewPage extends ConsumerWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);

    return stats.when(
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(
        message: error is AppFailure
            ? error.message
            : 'Unable to load dashboard data. Please try again.',
        onRetry: () => ref.invalidate(dashboardStatsProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardStatsProvider.future),
        child: _Dashboard(
          stats: data,
          onRefresh: () => ref.invalidate(dashboardStatsProvider),
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.stats, required this.onRefresh});

  final DashboardStats stats;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _Hero(stats: stats, onRefresh: onRefresh),
            const SizedBox(height: 20),
            _AttentionPanel(stats: stats),
            _KpiGrid(stats: stats),
            const SizedBox(height: 20),
            _ResponsivePair(
              wide: wide,
              first: _ChartCard(
                title: 'Uploads',
                subtitle: 'Posts added per day · last 30 days',
                child: DailyBarChart(days: stats.postsByDay, unit: 'upload'),
              ),
              second: _ChartCard(
                title: 'New users',
                subtitle: 'Sign-ups per day · last 30 days',
                child: DailyBarChart(days: stats.usersByDay, unit: 'sign-up'),
              ),
            ),
            const SizedBox(height: 20),
            _CategoryHealth(stats: stats),
          ],
        );
      },
    );
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({
    required this.wide,
    required this.first,
    required this.second,
  });

  final bool wide;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(children: [first, const SizedBox(height: 20), second]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: 20),
          Expanded(child: second),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.stats, required this.onRefresh});

  final DashboardStats stats;
  final VoidCallback onRefresh;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uploads = stats.postsLast7d;
    final users = stats.usersLast7d;
    final summary = [
      uploads == 0
          ? 'No new posts this week'
          : '${_plural(uploads, 'new post')} this week',
      _plural(users, 'new user'),
      '${DateFormatters.compactCount(stats.subsActive)} active subscribers',
    ].join('  ·  ');

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF134E4A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -50,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 200,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormatters.mediumDate(DateTime.now()).toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_greeting 👋',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF115E59),
                    ),
                    onPressed: () => context.go(AppRoutes.upload),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Upload content'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: () => context.go(AppRoutes.library),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Content library'),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    color: Colors.white,
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Things that need the admin's action, most important first. Hidden when
/// there is nothing to do.
class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <Widget>[
      for (final orphan in stats.orphanCategories)
        _AttentionItem(
          severity: _Severity.critical,
          title: '${_plural(orphan.count, 'post')} hidden from users',
          detail: 'They use the category "${orphan.name}", which no longer '
              'exists. Move them into a real category.',
          actionLabel: 'Review & fix',
          onAction: () => context.go(
            Uri(
              path: AppRoutes.library,
              queryParameters: {'category': orphan.name},
            ).toString(),
          ),
        ),
      for (final category in stats.emptyHomeCategories)
        _AttentionItem(
          severity: _Severity.warning,
          title: '"${category.name}" is on the home screen but empty',
          detail: 'Users see an empty section. Upload posts or hide it from '
              'home in Categories.',
          actionLabel: 'Upload',
          onAction: () => context.go(AppRoutes.upload),
        ),
      if (stats.staleHomeCategories().isNotEmpty)
        _AttentionItem(
          severity: _Severity.info,
          title: '${_plural(stats.staleHomeCategories().length, 'home category', plural: 'home categories')} '
              'with nothing new in 3 weeks',
          detail: _staleSummary(stats.staleHomeCategories()),
          actionLabel: 'Upload',
          onAction: () => context.go(AppRoutes.upload),
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Needs your attention',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CountPill(count: items.length),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                items[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _Severity { critical, warning, info }

class _AttentionItem extends StatelessWidget {
  const _AttentionItem({
    required this.severity,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.onAction,
  });

  final _Severity severity;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, label) = switch (severity) {
      _Severity.critical => (
          Icons.error_outline_rounded,
          const Color(0xFFC62828),
          'Fix now',
        ),
      _Severity.warning => (
          Icons.warning_amber_rounded,
          const Color(0xFFB45309),
          'Warning',
        ),
      _Severity.info => (
          Icons.schedule_rounded,
          const Color(0xFF475569),
          'Suggestion',
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _KpiTile(
        icon: Icons.photo_library_outlined,
        label: 'Total posts',
        value: stats.postsTotal,
        trendCurrent: stats.postsLast7d,
        trendPrevious: stats.postsPrev7d,
        trendUnit: 'uploaded',
        footer: _SplitBar(
          parts: [
            ('Images', stats.postsImages),
            ('Videos', stats.postsVideos),
          ],
        ),
      ),
      _KpiTile(
        icon: Icons.people_alt_outlined,
        label: 'Users',
        value: stats.usersTotal,
        trendCurrent: stats.usersLast7d,
        trendPrevious: stats.usersPrev7d,
        trendUnit: 'joined',
      ),
      _KpiTile(
        icon: Icons.workspace_premium_outlined,
        label: 'Active subscribers',
        value: stats.subsActive,
        caption: stats.subsRenewing7d == 0
            ? 'No renewals due this week'
            : '${_plural(stats.subsRenewing7d, 'renewal')} due in 7 days',
      ),
      _KpiTile(
        icon: Icons.hourglass_bottom_rounded,
        label: 'Checkout not finished',
        value: stats.subsPending,
        caption: 'Started a subscription but never paid',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;
        const gap = 20.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trendCurrent,
    this.trendPrevious,
    this.trendUnit,
    this.caption,
    this.footer,
  });

  final IconData icon;
  final String label;
  final int value;
  final int? trendCurrent;
  final int? trendPrevious;
  final String? trendUnit;
  final String? caption;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 132,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                DateFormatters.compactCount(value),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 10),
              if (trendCurrent != null)
                _Trend(
                  current: trendCurrent!,
                  previous: trendPrevious ?? 0,
                  unit: trendUnit ?? '',
                )
              else if (caption != null)
                Text(
                  caption!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// "+4 joined this week" with an arrow comparing to the previous week.
/// Direction is shown by icon and words, not colour alone.
class _Trend extends StatelessWidget {
  const _Trend({
    required this.current,
    required this.previous,
    required this.unit,
  });

  final int current;
  final int previous;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = current > previous;
    final flat = current == previous;
    final color = flat
        ? theme.colorScheme.onSurfaceVariant
        : up
            ? const Color(0xFF15803D)
            : const Color(0xFFB45309);
    final icon = flat
        ? Icons.trending_flat_rounded
        : up
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded;

    return Tooltip(
      message: 'Last 7 days: $current · previous 7 days: $previous',
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '+$current $unit this week · $previous the week before',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-part proportion bar with direct labels (no legend needed).
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.parts});

  final List<(String, int)> parts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = parts.fold(0, (sum, p) => sum + p.$2);
    final colors = [scheme.primary, const Color(0xFF7C3AED)];
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                for (var i = 0; i < parts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: parts[i].$2 == 0 ? 0 : parts[i].$2,
                    child: ColoredBox(color: colors[i % colors.length]),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${parts[i].$1} ${parts[i].$2}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _CategoryHealth extends StatelessWidget {
  const _CategoryHealth({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxCount = stats.categories.fold(
      1,
      (max, c) => c.count > max ? c.count : max,
    );
    final stale = stats.staleHomeCategories().map((c) => c.name).toSet();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Categories',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Posts per category and how fresh each one is',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.categories),
                  child: const Text('Manage categories'),
                ),
              ],
            ),
          ),
          Container(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: DefaultTextStyle.merge(
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Category')),
                  Expanded(flex: 4, child: Text('Posts')),
                  Expanded(flex: 2, child: Text('Last upload')),
                  SizedBox(width: 160, child: Text('Status')),
                ],
              ),
            ),
          ),
          for (final category in stats.categories) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => context.go(
                Uri(
                  path: AppRoutes.library,
                  queryParameters: {'category': category.name},
                ).toString(),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              category.name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (category.showOnHome) ...[
                            const SizedBox(width: 8),
                            Tooltip(
                              message: 'Shown on the app home screen',
                              child: Icon(
                                Icons.home_outlined,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: '${category.name}: '
                                  '${_plural(category.count, 'post')}',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: category.count / maxCount,
                                  minHeight: 8,
                                  color: scheme.primary,
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${category.count}',
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormatters.relativeDate(category.lastUpload),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _StatusChip.forCategory(
                          category,
                          isStale: stale.contains(category.name),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  factory _StatusChip.forCategory(
    CategoryStat category, {
    required bool isStale,
  }) {
    if (category.count == 0 && category.showOnHome) {
      return const _StatusChip(
        label: 'Empty on home',
        icon: Icons.warning_amber_rounded,
        color: Color(0xFFB45309),
      );
    }
    if (category.count == 0) {
      return const _StatusChip(
        label: 'No posts',
        icon: Icons.remove_circle_outline_rounded,
        color: Color(0xFF64748B),
      );
    }
    if (isStale) {
      return const _StatusChip(
        label: 'Needs fresh posts',
        icon: Icons.schedule_rounded,
        color: Color(0xFF475569),
      );
    }
    return const _StatusChip(
      label: 'Healthy',
      icon: Icons.check_circle_outline_rounded,
      color: Color(0xFF15803D),
    );
  }

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insights_outlined,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Dashboard unavailable',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _staleSummary(List<CategoryStat> stale) {
  const shown = 4;
  final names = stale
      .take(shown)
      .map((c) => '${c.name} (${DateFormatters.relativeDate(c.lastUpload)})')
      .join(', ');
  final rest = stale.length - shown;
  return rest > 0 ? '$names and $rest more' : names;
}

String _plural(int count, String singular, {String? plural}) {
  if (count == 1) return '1 $singular';
  return '${DateFormatters.compactCount(count)} ${plural ?? '${singular}s'}';
}
