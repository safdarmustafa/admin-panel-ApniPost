/// Small date helpers without adding an intl dependency.
abstract final class DateFormatters {
  static const _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String mediumDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  /// "Today", "Yesterday", "5 days ago", then a medium date after a month.
  static String relativeDate(DateTime? value, {DateTime? now}) {
    if (value == null) return '—';
    final local = value.toLocal();
    final today = _dateOnly(now ?? DateTime.now());
    final days = today.difference(_dateOnly(local)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 30) return '$days days ago';
    return mediumDate(value);
  }

  /// e.g. "Sep 9, 2026 · 10:27 PM".
  static String dateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '${mediumDate(local)} · $hour:$minute $period';
  }

  /// e.g. "Sep 9" — compact axis/tooltip label.
  static String shortDate(DateTime value) =>
      '${_months[value.month - 1]} ${value.day}';

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String compactCount(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final reverseIndex = raw.length - i;
      buffer.write(raw[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}
