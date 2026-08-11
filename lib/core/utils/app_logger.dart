import 'dart:developer' as developer;

import 'package:apnipost_admin/core/config/app_config.dart';

/// Lightweight logger that avoids secrets and can be quiet in production.
abstract final class AppLogger {
  static void info(String message, {String name = 'apnipost_admin'}) {
    if (!AppConfig.enableVerboseLogging) return;
    developer.log(message, name: name);
  }

  static void warn(String message, {String name = 'apnipost_admin'}) {
    developer.log(message, name: name, level: 900);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String name = 'apnipost_admin',
  }) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }
}
