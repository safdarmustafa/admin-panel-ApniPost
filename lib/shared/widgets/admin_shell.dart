import 'package:apnipost_admin/core/constants/app_routes.dart';
import 'package:apnipost_admin/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Desktop-first admin chrome: top bar + sidebar + content.
class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _destinations = <_NavDestination>[
    _NavDestination(
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      path: AppRoutes.overview,
    ),
    _NavDestination(
      label: 'Content Library',
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
      path: AppRoutes.library,
    ),
    _NavDestination(
      label: 'Categories',
      icon: Icons.category_outlined,
      selectedIcon: Icons.category,
      path: AppRoutes.categories,
    ),
    _NavDestination(
      label: 'Data Upload',
      icon: Icons.cloud_upload_outlined,
      selectedIcon: Icons.cloud_upload,
      path: AppRoutes.upload,
    ),
    _NavDestination(
      label: 'Ringtones',
      icon: Icons.music_note_outlined,
      selectedIcon: Icons.music_note,
      path: AppRoutes.ringtones,
    ),
    _NavDestination(
      label: 'Ringtone Categories',
      icon: Icons.queue_music_outlined,
      selectedIcon: Icons.queue_music,
      path: AppRoutes.ringtoneCategories,
    ),
  ];

  int _selectedIndex(String location) {
    final index = _destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(location);
    final userEmail =
        ref.watch(adminAccessProvider).asData?.value.user?.email;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1100,
            minExtendedWidth: 220,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              context.go(_destinations[index].path);
            },
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
              child: Column(
                children: [
                  Icon(
                    Icons.local_post_office_outlined,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ApniPost',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    'Admin',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            destinations: [
              for (final destination in _destinations)
                NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                ),
            ],
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Tooltip(
                message: 'Logout',
                child: IconButton(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    ref.invalidate(adminAccessProvider);
                    if (context.mounted) {
                      context.go(AppRoutes.login);
                    }
                  },
                  icon: const Icon(Icons.logout),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: theme.colorScheme.surface,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Text(
                              _destinations[selectedIndex].label,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (userEmail != null)
                              Text(
                                userEmail,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}
