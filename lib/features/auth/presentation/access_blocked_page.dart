import 'package:apnipost_admin/core/constants/app_routes.dart';
import 'package:apnipost_admin/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shown when a user is signed in but not authorized for admin access.
class AccessBlockedPage extends ConsumerStatefulWidget {
  const AccessBlockedPage({super.key});

  @override
  ConsumerState<AccessBlockedPage> createState() => _AccessBlockedPageState();
}

class _AccessBlockedPageState extends ConsumerState<AccessBlockedPage> {
  bool _refreshing = false;
  bool _didAutoRefresh = false;

  @override
  void initState() {
    super.initState();
    // One-shot session refresh in case app_metadata.role was assigned after
    // the current JWT was issued. Does not loop continuously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_didAutoRefresh) {
        _didAutoRefresh = true;
        _refreshAccess(showBusy: false);
      }
    });
  }

  Future<void> _refreshAccess({required bool showBusy}) async {
    if (_refreshing) return;
    setState(() => _refreshing = showBusy);
    try {
      await ref.read(authRepositoryProvider).refreshSession();
      ref.invalidate(authUserProvider);
      ref.invalidate(adminAccessProvider);
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(authUserProvider);
    ref.invalidate(adminAccessProvider);
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final access = ref.watch(adminAccessProvider).asData?.value;
    final message = access?.message ??
        'Your account is not authorized to access ApniPost Admin.';

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 40,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Access blocked',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
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
                  const SizedBox(height: 8),
                  Text(
                    'If an administrator just granted you access, use '
                    '"Check access again" after your role is set in '
                    'Supabase app_metadata.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_refreshing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  OutlinedButton(
                    onPressed:
                        _refreshing ? null : () => _refreshAccess(showBusy: true),
                    child: const Text('Check access again'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refreshing ? null : _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
