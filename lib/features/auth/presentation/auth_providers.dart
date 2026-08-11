import 'package:apnipost_admin/core/config/app_config.dart';
import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/auth/data/app_metadata_admin_authorization_repository.dart';
import 'package:apnipost_admin/features/auth/data/supabase_auth_repository.dart';
import 'package:apnipost_admin/features/auth/domain/admin_authorization.dart';
import 'package:apnipost_admin/features/auth/domain/auth_repository.dart';
import 'package:apnipost_admin/features/auth/domain/auth_user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (!SupabaseBootstrap.isInitialized) {
    return const _UnconfiguredAuthRepository();
  }
  return SupabaseAuthRepository();
});

final adminAuthorizationRepositoryProvider =
    Provider<AdminAuthorizationRepository>((ref) {
  return const AppMetadataAdminAuthorizationRepository();
});

/// Current Supabase session user (null when signed out).
final authUserProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

/// Combined auth + admin authorization state for routing and UI.
final adminAccessProvider = FutureProvider<AdminAccessState>((ref) async {
  if (!AppConfig.isSupabaseConfigured || !SupabaseBootstrap.isInitialized) {
    return const AdminAccessState.unconfigured();
  }

  final authAsync = ref.watch(authUserProvider);
  final user = authAsync.asData?.value ??
      ref.read(authRepositoryProvider).currentUser;

  // While auth stream is loading and we have no current user yet, stay loading.
  if (authAsync.isLoading && user == null) {
    return const AdminAccessState.loading();
  }

  if (user == null) {
    return const AdminAccessState.unauthenticated();
  }

  final authz = await ref
      .read(adminAuthorizationRepositoryProvider)
      .authorize(user);

  return AdminAccessState.fromAuthorization(user: user, result: authz);
});

class AdminAccessState {
  const AdminAccessState._({
    required this.status,
    this.user,
    this.message,
  });

  const AdminAccessState.loading()
      : this._(status: AdminAccessStatus.loading);

  const AdminAccessState.unconfigured()
      : this._(
          status: AdminAccessStatus.unconfigured,
          message:
              'Supabase is not configured. Provide SUPABASE_URL and '
              'SUPABASE_ANON_KEY via --dart-define.',
        );

  const AdminAccessState.unauthenticated()
      : this._(status: AdminAccessStatus.unauthenticated);

  factory AdminAccessState.fromAuthorization({
    required AppUser user,
    required AdminAuthorizationResult result,
  }) {
    switch (result.status) {
      case AdminAuthStatus.authorized:
        return AdminAccessState._(
          status: AdminAccessStatus.authorized,
          user: user,
        );
      case AdminAuthStatus.denied:
        return AdminAccessState._(
          status: AdminAccessStatus.denied,
          user: user,
          message: result.message,
        );
      case AdminAuthStatus.error:
        return AdminAccessState._(
          status: AdminAccessStatus.error,
          user: user,
          message: result.message,
        );
    }
  }

  final AdminAccessStatus status;
  final AppUser? user;
  final String? message;

  bool get isAuthorized => status == AdminAccessStatus.authorized;
  bool get isAuthenticated => user != null;
}

enum AdminAccessStatus {
  loading,
  unconfigured,
  unauthenticated,
  authorized,
  denied,
  error,
}

class _UnconfiguredAuthRepository implements AuthRepository {
  const _UnconfiguredAuthRepository();

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    throw const AppFailure(
      'Supabase is not configured. Provide SUPABASE_URL and '
      'SUPABASE_ANON_KEY via --dart-define.',
    );
  }

  @override
  Future<AppUser?> refreshSession() async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    throw const AppFailure(
      'Supabase is not configured. Provide SUPABASE_URL and '
      'SUPABASE_ANON_KEY via --dart-define.',
    );
  }

  @override
  Future<void> signOut() async {}
}
