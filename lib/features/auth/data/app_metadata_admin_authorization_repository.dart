import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/auth/domain/admin_authorization.dart';
import 'package:apnipost_admin/features/auth/domain/auth_user.dart';

/// Authorizes admins from Supabase JWT `app_metadata.role`.
///
/// Only `role == "admin"` is allowed. Does not read `user_metadata`,
/// `public.users`, or email allowlists.
class AppMetadataAdminAuthorizationRepository
    implements AdminAuthorizationRepository {
  const AppMetadataAdminAuthorizationRepository();

  @override
  Future<AdminAuthorizationResult> authorize(AppUser? user) async {
    try {
      final result = AdminAuthorizationEvaluator.evaluateUser(user);
      if (result.isAuthorized) {
        AppLogger.info('Admin authorization granted for user=${user?.id}');
      } else {
        AppLogger.info(
          'Admin authorization denied for user=${user?.id} '
          'status=${result.status.name}',
        );
      }
      return result;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Admin authorization failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      return const AdminAuthorizationResult.error();
    }
  }
}
