import 'package:apnipost_admin/features/auth/domain/auth_user.dart';

/// Result of the admin authorization check.
///
/// Authorization must fail closed. A valid Supabase login alone is not enough.
enum AdminAuthStatus {
  /// User is authorized to use the admin panel.
  authorized,

  /// User is authenticated but not an admin (or not signed in).
  denied,

  /// Backend/authz lookup failed unexpectedly.
  error,
}

class AdminAuthorizationResult {
  const AdminAuthorizationResult({
    required this.status,
    this.message,
  });

  const AdminAuthorizationResult.authorized()
      : status = AdminAuthStatus.authorized,
        message = null;

  const AdminAuthorizationResult.denied([
    this.message = 'Your account is not authorized to access ApniPost Admin.',
  ]) : status = AdminAuthStatus.denied;

  const AdminAuthorizationResult.error([
    this.message = 'Unable to verify admin access. Please try again.',
  ]) : status = AdminAuthStatus.error;

  final AdminAuthStatus status;
  final String? message;

  bool get isAuthorized => status == AdminAuthStatus.authorized;
}

/// Pure, fail-closed admin role evaluation from JWT app_metadata.
///
/// Authorized only when [appMetadata] contains `role` == `"admin"`.
abstract final class AdminAuthorizationEvaluator {
  static const String adminRole = 'admin';

  static AdminAuthorizationResult evaluate({
    required bool isAuthenticated,
    Map<String, dynamic>? appMetadata,
  }) {
    try {
      if (!isAuthenticated) {
        return const AdminAuthorizationResult.denied(
          'Sign in required to access ApniPost Admin.',
        );
      }

      if (appMetadata == null) {
        return const AdminAuthorizationResult.denied(
          'Your account is not authorized to access ApniPost Admin.',
        );
      }

      if (!appMetadata.containsKey('role')) {
        return const AdminAuthorizationResult.denied(
          'Your account is not authorized to access ApniPost Admin.',
        );
      }

      final role = appMetadata['role'];
      if (role is! String) {
        return const AdminAuthorizationResult.denied(
          'Your account is not authorized to access ApniPost Admin.',
        );
      }

      if (role == adminRole) {
        return const AdminAuthorizationResult.authorized();
      }

      return const AdminAuthorizationResult.denied(
        'Your account is not authorized to access ApniPost Admin.',
      );
    } catch (_) {
      return const AdminAuthorizationResult.error();
    }
  }

  static AdminAuthorizationResult evaluateUser(AppUser? user) {
    return evaluate(
      isAuthenticated: user != null,
      appMetadata: user?.appMetadata,
    );
  }
}

/// Isolated admin authorization contract.
abstract class AdminAuthorizationRepository {
  /// Returns authorized only for JWT `app_metadata.role == "admin"`.
  ///
  /// Must never throw; failures return [AdminAuthorizationResult.error].
  Future<AdminAuthorizationResult> authorize(AppUser? user);
}
