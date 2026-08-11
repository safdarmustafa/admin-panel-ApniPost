import 'package:apnipost_admin/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unauthenticated app lands on login', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ApniPostAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ApniPost Admin'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });
}
