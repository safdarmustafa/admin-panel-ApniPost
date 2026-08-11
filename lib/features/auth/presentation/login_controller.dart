import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/auth/presentation/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoginFormStatus {
  idle,
  submitting,
  resetSending,
  resetSent,
  error,
}

@immutable
class LoginFormState {
  const LoginFormState({
    this.status = LoginFormStatus.idle,
    this.errorMessage,
    this.infoMessage,
    this.obscurePassword = true,
  });

  final LoginFormStatus status;
  final String? errorMessage;
  final String? infoMessage;
  final bool obscurePassword;

  bool get isBusy =>
      status == LoginFormStatus.submitting ||
      status == LoginFormStatus.resetSending;

  LoginFormState copyWith({
    LoginFormStatus? status,
    String? errorMessage,
    String? infoMessage,
    bool? obscurePassword,
    bool clearMessages = false,
  }) {
    return LoginFormState(
      status: status ?? this.status,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearMessages ? null : (infoMessage ?? this.infoMessage),
      obscurePassword: obscurePassword ?? this.obscurePassword,
    );
  }
}

class LoginController extends StateNotifier<LoginFormState> {
  LoginController(this._ref) : super(const LoginFormState());

  final Ref _ref;

  void togglePasswordVisibility() {
    if (!mounted) return;
    state = state.copyWith(obscurePassword: !state.obscurePassword);
  }

  void clearMessages() {
    if (!mounted) return;
    state = state.copyWith(clearMessages: true, status: LoginFormStatus.idle);
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      _setStateIfMounted(
        state.copyWith(
          status: LoginFormStatus.error,
          errorMessage: 'Enter your email and password.',
          infoMessage: null,
        ),
      );
      return false;
    }
    if (!_looksLikeEmail(trimmedEmail)) {
      _setStateIfMounted(
        state.copyWith(
          status: LoginFormStatus.error,
          errorMessage: 'Enter a valid email address.',
          infoMessage: null,
        ),
      );
      return false;
    }

    _setStateIfMounted(
      state.copyWith(
        status: LoginFormStatus.submitting,
        clearMessages: true,
      ),
    );

    try {
      await _ref.read(authRepositoryProvider).signInWithEmailPassword(
            email: trimmedEmail,
            password: password,
          );
      // Sign-in success can redirect away from /login immediately and dispose
      // this autoDispose controller before the Future finishes.
      if (!mounted) return true;

      // Invalidate so admin access is re-checked immediately.
      _ref.invalidate(adminAccessProvider);
      if (!mounted) return true;

      state = state.copyWith(status: LoginFormStatus.idle);
      return true;
    } on AppFailure catch (failure) {
      if (!mounted) return false;
      state = state.copyWith(
        status: LoginFormStatus.error,
        errorMessage: failure.message,
      );
      return false;
    } catch (_) {
      if (!mounted) return false;
      state = state.copyWith(
        status: LoginFormStatus.error,
        errorMessage: 'Unable to sign in. Please try again.',
      );
      return false;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !_looksLikeEmail(trimmedEmail)) {
      _setStateIfMounted(
        state.copyWith(
          status: LoginFormStatus.error,
          errorMessage: 'Enter a valid email to reset your password.',
          infoMessage: null,
        ),
      );
      return;
    }

    _setStateIfMounted(
      state.copyWith(
        status: LoginFormStatus.resetSending,
        clearMessages: true,
      ),
    );

    try {
      await _ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(trimmedEmail);
      if (!mounted) return;
      state = state.copyWith(
        status: LoginFormStatus.resetSent,
        infoMessage:
            'If an account exists for that email, a reset link has been sent.',
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      state = state.copyWith(
        status: LoginFormStatus.error,
        errorMessage: failure.message,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        status: LoginFormStatus.error,
        errorMessage: 'Unable to send reset email. Please try again.',
      );
    }
  }

  void _setStateIfMounted(LoginFormState next) {
    if (!mounted) return;
    state = next;
  }

  bool _looksLikeEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }
}

final loginControllerProvider =
    StateNotifierProvider.autoDispose<LoginController, LoginFormState>((ref) {
  return LoginController(ref);
});
