import 'package:apnipost_admin/features/auth/data/app_metadata_admin_authorization_repository.dart';
import 'package:apnipost_admin/features/auth/domain/admin_authorization.dart';
import 'package:apnipost_admin/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = AppMetadataAdminAuthorizationRepository();

  group('AdminAuthorizationEvaluator', () {
    test('denies when there is no authenticated user', () {
      final result = AdminAuthorizationEvaluator.evaluateUser(null);

      expect(result.status, AdminAuthStatus.denied);
      expect(result.isAuthorized, isFalse);
    });

    test('denies authenticated user with no app_metadata map content', () {
      final result = AdminAuthorizationEvaluator.evaluate(
        isAuthenticated: true,
        appMetadata: null,
      );

      expect(result.status, AdminAuthStatus.denied);
      expect(result.isAuthorized, isFalse);
    });

    test('denies authenticated user with empty app_metadata (no role)', () {
      final result = AdminAuthorizationEvaluator.evaluateUser(
        const AppUser(id: 'u1', email: 'a@b.com'),
      );

      expect(result.status, AdminAuthStatus.denied);
      expect(result.isAuthorized, isFalse);
    });

    test('denies authenticated user with role = user', () {
      final result = AdminAuthorizationEvaluator.evaluateUser(
        const AppUser(
          id: 'u1',
          email: 'a@b.com',
          appMetadata: {'role': 'user'},
        ),
      );

      expect(result.status, AdminAuthStatus.denied);
      expect(result.isAuthorized, isFalse);
    });

    test('authorizes authenticated user with role = admin', () {
      final result = AdminAuthorizationEvaluator.evaluateUser(
        const AppUser(
          id: 'u1',
          email: 'a@b.com',
          appMetadata: {'role': 'admin'},
        ),
      );

      expect(result.status, AdminAuthStatus.authorized);
      expect(result.isAuthorized, isTrue);
    });

    test('denies unexpected role values', () {
      final cases = <dynamic>[
        'Admin',
        'ADMIN',
        'administrator',
        'moderator',
        '',
        1,
        true,
        ['admin'],
        {'name': 'admin'},
      ];

      for (final role in cases) {
        final result = AdminAuthorizationEvaluator.evaluate(
          isAuthenticated: true,
          appMetadata: {'role': role},
        );
        expect(
          result.isAuthorized,
          isFalse,
          reason: 'role=$role should be denied',
        );
        expect(result.status, AdminAuthStatus.denied);
      }
    });

    test('returns error on authorization failure', () {
      final result = AdminAuthorizationEvaluator.evaluate(
        isAuthenticated: true,
        appMetadata: _ThrowingMap(),
      );

      expect(result.status, AdminAuthStatus.error);
      expect(result.isAuthorized, isFalse);
    });

    test('authorization success helper matches authorized factory', () {
      const result = AdminAuthorizationResult.authorized();
      expect(result.isAuthorized, isTrue);
      expect(result.status, AdminAuthStatus.authorized);
    });
  });

  group('AppMetadataAdminAuthorizationRepository', () {
    test('no authenticated user → denied', () async {
      final result = await repository.authorize(null);
      expect(result.status, AdminAuthStatus.denied);
      expect(result.isAuthorized, isFalse);
    });

    test('no app_metadata role → denied', () async {
      final result = await repository.authorize(
        const AppUser(id: 'u1', email: 'a@b.com'),
      );
      expect(result.isAuthorized, isFalse);
    });

    test('role user → denied', () async {
      final result = await repository.authorize(
        const AppUser(
          id: 'u1',
          email: 'a@b.com',
          appMetadata: {'role': 'user'},
        ),
      );
      expect(result.isAuthorized, isFalse);
    });

    test('role admin → authorized', () async {
      final result = await repository.authorize(
        const AppUser(
          id: 'u1',
          email: 'admin@example.com',
          appMetadata: {'role': 'admin'},
        ),
      );
      expect(result.status, AdminAuthStatus.authorized);
      expect(result.isAuthorized, isTrue);
    });

    test('never throws on unexpected map access failures', () async {
      final result = await repository.authorize(
        AppUser(
          id: 'u1',
          email: 'a@b.com',
          appMetadata: _ThrowingMap(),
        ),
      );
      expect(result.status, AdminAuthStatus.error);
      expect(result.isAuthorized, isFalse);
    });
  });

  group('AppUser.hasAdminRole', () {
    test('true only for exact admin role string', () {
      expect(
        const AppUser(
          id: '1',
          email: null,
          appMetadata: {'role': 'admin'},
        ).hasAdminRole,
        isTrue,
      );
      expect(
        const AppUser(
          id: '1',
          email: null,
          appMetadata: {'role': 'user'},
        ).hasAdminRole,
        isFalse,
      );
      expect(const AppUser(id: '1', email: null).hasAdminRole, isFalse);
    });
  });
}

/// Map that throws when reading keys — simulates unexpected metadata failures.
class _ThrowingMap implements Map<String, dynamic> {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError('simulated metadata failure');
  }
}
