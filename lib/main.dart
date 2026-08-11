import 'package:apnipost_admin/core/config/app_config.dart';
import 'package:apnipost_admin/core/config/supabase_bootstrap.dart';
import 'package:apnipost_admin/core/router/app_router.dart';
import 'package:apnipost_admin/core/theme/app_theme.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseBootstrap.initialize();
  } catch (error, stackTrace) {
    AppLogger.error(
      'Failed to initialize Supabase',
      error: error,
      stackTrace: stackTrace,
    );
  }

  runApp(
    const ProviderScope(
      child: ApniPostAdminApp(),
    ),
  );
}

class ApniPostAdminApp extends ConsumerWidget {
  const ApniPostAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
