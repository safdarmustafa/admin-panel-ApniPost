/// Application-wide safe configuration.
///
/// Secrets must never be hardcoded. Provide public values via `--dart-define`:
///
/// ```
/// --dart-define=SUPABASE_URL=...
/// --dart-define=SUPABASE_ANON_KEY=...
/// ```
abstract final class AppConfig {
  static const String appName = 'ApniPost Admin';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Whether public Supabase values were supplied at build/run time.
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Verbose logging for development. Disable for production builds.
  static const bool enableVerboseLogging = bool.fromEnvironment(
    'VERBOSE_LOGGING',
    defaultValue: false,
  );
}
