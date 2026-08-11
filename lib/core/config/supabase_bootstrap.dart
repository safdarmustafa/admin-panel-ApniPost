import 'package:apnipost_admin/core/config/app_config.dart';
import 'package:apnipost_admin/core/utils/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes Supabase when safe public configuration is present.
///
/// Does not invent credentials. If URL/anon key are missing, initialization
/// is skipped and the UI can surface a configuration message.
abstract final class SupabaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!AppConfig.isSupabaseConfigured) {
      AppLogger.warn(
        'Supabase is not configured. Pass SUPABASE_URL and '
        'SUPABASE_ANON_KEY via --dart-define.',
      );
      return;
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _initialized = true;
    AppLogger.info('Supabase initialized');
  }

  /// Returns the client only after successful initialization.
  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not initialized. Provide SUPABASE_URL and '
        'SUPABASE_ANON_KEY, then call SupabaseBootstrap.initialize().',
      );
    }
    return Supabase.instance.client;
  }
}
