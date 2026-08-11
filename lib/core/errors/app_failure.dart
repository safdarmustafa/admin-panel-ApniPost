import 'package:flutter/foundation.dart';

/// User-facing failure with optional technical detail for debugging.
@immutable
class AppFailure implements Exception {
  const AppFailure(
    this.message, {
    this.cause,
  });

  /// Safe message suitable for UI display.
  final String message;

  /// Underlying technical error (never show raw to end users).
  final Object? cause;

  @override
  String toString() => 'AppFailure($message)';
}
