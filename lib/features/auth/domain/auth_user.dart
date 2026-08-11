import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authenticated user representation for the admin app.
///
/// Named `AppUser` to avoid clashing with Supabase's `AuthUser` type.
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.appMetadata = const <String, dynamic>{},
  });

  final String id;
  final String? email;

  /// Claims from the Supabase JWT `app_metadata` object.
  final Map<String, dynamic> appMetadata;

  factory AppUser.fromSupabase(User user) {
    return AppUser(
      id: user.id,
      email: user.email,
      appMetadata: Map<String, dynamic>.from(user.appMetadata),
    );
  }

  /// True when JWT app_metadata.role is exactly "admin".
  bool get hasAdminRole {
    final role = appMetadata['role'];
    return role is String && role == 'admin';
  }
}
