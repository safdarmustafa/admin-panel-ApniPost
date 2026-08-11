import 'package:apnipost_admin/features/auth/domain/auth_user.dart';

/// Authentication operations backed by Supabase Auth.
abstract class AuthRepository {
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  /// Reloads the session once so JWT claims (including app_metadata) refresh.
  ///
  /// Returns the refreshed user, or null when signed out.
  Future<AppUser?> refreshSession();

  Future<void> signOut();
}
