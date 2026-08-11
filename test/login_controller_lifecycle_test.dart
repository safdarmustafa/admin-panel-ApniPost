import 'dart:async';

import 'package:apnipost_admin/core/errors/app_failure.dart';
import 'package:apnipost_admin/features/auth/domain/auth_repository.dart';
import 'package:apnipost_admin/features/auth/domain/auth_user.dart';
import 'package:apnipost_admin/features/auth/presentation/auth_providers.dart';
import 'package:apnipost_admin/features/auth/presentation/login_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControllableAuthRepository implements AuthRepository {
  Completer<AppUser>? signInCompleter;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AppUser> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    final completer = Completer<AppUser>();
    signInCompleter = completer;
    return completer.future;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AppUser?> refreshSession() async => null;

  @override
  Future<void> signOut() async {}
}

void main() {
  const email = 'admin@example.com';
  const password = 'secret-password';

  test('successful login while controller remains alive updates state', () async {
    final auth = _ControllableAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);

    // Keep autoDispose provider alive for the duration of the test.
    final sub = container.listen(
      loginControllerProvider,
      (previous, next) {},
    );
    addTearDown(sub.close);

    final controller = container.read(loginControllerProvider.notifier);
    final future = controller.signIn(email: email, password: password);

    expect(
      container.read(loginControllerProvider).status,
      LoginFormStatus.submitting,
    );

    auth.signInCompleter!.complete(
      const AppUser(
        id: 'user-1',
        email: email,
        appMetadata: {'role': 'admin'},
      ),
    );

    final ok = await future;
    expect(ok, isTrue);
    expect(controller.mounted, isTrue);
    expect(
      container.read(loginControllerProvider).status,
      LoginFormStatus.idle,
    );
  });

  test(
    'controller disposed before async login completes does not throw',
    () async {
      final auth = _ControllableAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        loginControllerProvider,
        (previous, next) {},
      );
      final controller = container.read(loginControllerProvider.notifier);
      final future = controller.signIn(email: email, password: password);

      // Simulate leaving /login: no listeners remain → autoDispose.
      sub.close();
      await pumpEventQueue();
      expect(controller.mounted, isFalse);

      auth.signInCompleter!.complete(
        const AppUser(
          id: 'user-1',
          email: email,
          appMetadata: {'role': 'admin'},
        ),
      );

      await expectLater(future, completion(isTrue));
      expect(controller.mounted, isFalse);
    },
  );

  test(
    'async failure after disposal must not access state or throw',
    () async {
      final auth = _ControllableAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        loginControllerProvider,
        (previous, next) {},
      );
      final controller = container.read(loginControllerProvider.notifier);
      final future = controller.signIn(email: email, password: password);

      sub.close();
      await pumpEventQueue();
      expect(controller.mounted, isFalse);

      auth.signInCompleter!.completeError(
        const AppFailure('Incorrect email or password.'),
      );

      await expectLater(future, completion(isFalse));
      expect(controller.mounted, isFalse);
    },
  );
}
