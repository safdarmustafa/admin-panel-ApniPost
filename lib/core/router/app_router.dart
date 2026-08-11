import 'package:apnipost_admin/core/constants/app_routes.dart';
import 'package:apnipost_admin/features/auth/presentation/access_blocked_page.dart';
import 'package:apnipost_admin/features/auth/presentation/auth_providers.dart';
import 'package:apnipost_admin/features/auth/presentation/login_page.dart';
import 'package:apnipost_admin/features/categories/presentation/categories_page.dart';
import 'package:apnipost_admin/features/data_upload/presentation/data_upload_page.dart';
import 'package:apnipost_admin/features/overview/presentation/overview_page.dart';
import 'package:apnipost_admin/shared/widgets/admin_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier<int>(0);
  ref.listen<AsyncValue<AdminAccessState>>(adminAccessProvider, (previous, next) {
    refreshListenable.value++;
  });
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.overview,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final accessAsync = ref.read(adminAccessProvider);

      final isLogin = location == AppRoutes.login;
      final isBlocked = location == AppRoutes.accessBlocked;

      // Keep current page while auth state resolves to avoid login flash.
      if (accessAsync.isLoading ||
          (accessAsync.isRefreshing && accessAsync.asData == null)) {
        return null;
      }

      final access = accessAsync.asData?.value;
      if (access == null) {
        return isLogin ? null : AppRoutes.login;
      }

      switch (access.status) {
        case AdminAccessStatus.loading:
          return null;
        case AdminAccessStatus.unconfigured:
        case AdminAccessStatus.unauthenticated:
          return isLogin ? null : AppRoutes.login;
        case AdminAccessStatus.authorized:
          if (isLogin || isBlocked) {
            return AppRoutes.overview;
          }
          return null;
        case AdminAccessStatus.denied:
        case AdminAccessStatus.error:
          if (isBlocked) return null;
          return AppRoutes.accessBlocked;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.accessBlocked,
        name: 'access-blocked',
        builder: (context, state) => const AccessBlockedPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.overview,
            name: 'overview',
            builder: (context, state) => const OverviewPage(),
          ),
          GoRoute(
            path: AppRoutes.categories,
            name: 'categories',
            builder: (context, state) => const CategoriesPage(),
          ),
          GoRoute(
            path: AppRoutes.upload,
            name: 'upload',
            builder: (context, state) => const DataUploadPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go(AppRoutes.overview),
                child: const Text('Go to overview'),
              ),
            ],
          ),
        ),
      );
    },
  );
});
