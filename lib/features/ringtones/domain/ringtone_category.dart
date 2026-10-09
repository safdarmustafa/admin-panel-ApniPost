import 'package:flutter/foundation.dart';

/// A row in `public.ringtone_categories`. The Android Ringtones screen builds
/// its chips from this table (in [displayOrder], labelled with [hindiName]).
@immutable
class RingtoneCategory {
  const RingtoneCategory({
    required this.id,
    required this.name,
    required this.hindiName,
    required this.displayOrder,
    required this.createdAt,
    this.ringtoneCount = 0,
  });

  final String id;

  /// English name; `ringtones.category` references it.
  final String name;
  final String? hindiName;
  final int displayOrder;
  final DateTime? createdAt;
  final int ringtoneCount;

  /// "Durga · दुर्गा" for dropdowns and chips.
  String get label =>
      hindiName == null || hindiName!.isEmpty ? name : '$name · $hindiName';

  factory RingtoneCategory.fromMap(Map<String, dynamic> map) {
    // `ringtones(count)` embeds as [{count: n}].
    final embedded = map['ringtones'];
    final count = embedded is List && embedded.isNotEmpty
        ? (embedded.first as Map)['count'] as num? ?? 0
        : 0;
    final hindi = (map['hindi_name'] as String?)?.trim();
    return RingtoneCategory(
      id: map['id'].toString(),
      name: (map['name'] as String?) ?? '',
      hindiName: hindi == null || hindi.isEmpty ? null : hindi,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      ringtoneCount: count.toInt(),
    );
  }

  RingtoneCategory copyWith({int? displayOrder}) {
    return RingtoneCategory(
      id: id,
      name: name,
      hindiName: hindiName,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt,
      ringtoneCount: ringtoneCount,
    );
  }
}
