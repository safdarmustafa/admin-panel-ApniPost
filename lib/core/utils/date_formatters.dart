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
