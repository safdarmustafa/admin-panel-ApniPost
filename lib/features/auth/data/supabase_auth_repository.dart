import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:apnipost_admin/features/auth/domain/auth_repository.dart';
import 'package:apnipost_admin/features/auth/domain/auth_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AppUser.fromSupabase(user);
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    // Emit restored session immediately so refresh/cold-start redirects work.
    yield currentUser;
    yield* _auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return AppUser.fromSupabase(user);
    });
  }

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    AppLogger.info('Auth sign-in started');
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AppFailure('Unable to sign in. Please try again.');
      }

      // One-shot refresh so freshly assigned app_metadata.role is visible.
      final refreshed = await refreshSession();
      AppLogger.info('Auth sign-in succeeded');
      return refreshed ?? AppUser.fromSupabase(user);
    } on AuthException catch (error, stackTrace) {
      AppLogger.error(
        'Auth sign-in failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapAuthMessage(error), cause: error);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Auth sign-in failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is AppFailure) rethrow;
      throw AppFailure(
        'Unable to sign in. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<AppUser?> refreshSession() async {
    AppLogger.info('Auth session refresh started');
    try {
      final response = await _auth.refreshSession();
      final user = response.user ?? _auth.currentUser;
      if (user == null) {
        AppLogger.info('Auth session refresh completed with no user');
        return null;
      }
      AppLogger.info('Auth session refresh succeeded');
      return AppUser.fromSupabase(user);
    } on AuthException catch (error, stackTrace) {
      AppLogger.error(
        'Auth session refresh failed',
        error: error,
        stackTrace: stackTrace,
      );
      // Fail soft: keep existing local session user if present.
      return currentUser;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Auth session refresh failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      return currentUser;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    AppLogger.info('Password reset requested');
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error, stackTrace) {
      AppLogger.error(
        'Password reset failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapAuthMessage(error), cause: error);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Password reset failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is AppFailure) rethrow;
      throw AppFailure(
        'Unable to send reset email. Please try again.',
        cause: error,
      );
    }
  }

  @override
  Future<void> signOut() async {
    AppLogger.info('Auth sign-out started');
    try {
      await _auth.signOut();
      AppLogger.info('Auth sign-out succeeded');
    } on AuthException catch (error, stackTrace) {
      AppLogger.error(
        'Auth sign-out failed',
        error: error,
        stackTrace: stackTrace,
      );
      throw AppFailure(_mapAuthMessage(error), cause: error);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Auth sign-out failed unexpectedly',
        error: error,
        stackTrace: stackTrace,
      );
      if (error is AppFailure) rethrow;
      throw AppFailure('Unable to sign out. Please try again.', cause: error);
    }
  }

  String _mapAuthMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (message.contains('too many requests') ||
        message.contains('rate limit')) {
      return 'Too many attempts. Please wait and try again.';
    }
    if (message.contains('user not found')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('network')) {
      return 'Network error. Check your connection and try again.';
    }
    return 'Unable to complete authentication. Please try again.';
  }
}
