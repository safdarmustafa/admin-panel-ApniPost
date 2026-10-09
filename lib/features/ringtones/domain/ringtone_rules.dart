/// Pure validation + naming rules for ringtones (mirrors the DB checks and
/// the `ringtone-r2` Edge Function).
abstract final class RingtoneRules {
  static const int minDurationSec = 1;
  static const int maxDurationSec = 60;

  /// Above this a ringtone loads slowly on mobile data (warning only).
  static const int sizeWarningBytes = 1024 * 1024;

  /// Matches `ringtone-r2` (proxy fallback is lower: 4 MB).
  static const int maxBytes = 10 * 1024 * 1024;
  static const int maxProxyBytes = 4 * 1024 * 1024;

  static const int maxCategoryLength = 50;
  static const int maxTitleLength = 120;

  static const String pickerAccept =
      'audio/mpeg,audio/mp4,audio/x-m4a,audio/ogg,.mp3,.m4a,.ogg';

  static const String mediaHost = 'media.apnipost.com';
  static const String objectPrefix = 'ringtones/';

  /// The app adds "सभी" (All) itself; never store it.
  static const Set<String> _reservedCategories = {'all', 'सभी'};

  static const _extensionContentTypes = {
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
  };

  static const _mimeContentTypes = {
    'audio/mpeg': 'audio/mpeg',
    'audio/mp3': 'audio/mpeg',
    'audio/mp4': 'audio/mp4',
    'audio/x-m4a': 'audio/mp4',
    'audio/m4a': 'audio/mp4',
    'audio/aac': 'audio/mp4',
    'audio/ogg': 'audio/ogg',
  };

  /// Upload Content-Type for a picked file, or null if unsupported.
  /// The extension wins because browsers report m4a inconsistently.
  static String? contentTypeFor(String fileName, String mimeType) {
    final dot = fileName.lastIndexOf('.');
    if (dot >= 0) {
      final ext = fileName.substring(dot + 1).toLowerCase();
      final byExt = _extensionContentTypes[ext];
      if (byExt != null) return byExt;
    }
    return _mimeContentTypes[mimeType.toLowerCase().trim()];
  }

  /// Whole seconds as stored in `duration_sec` (`Math.round`).
  static int roundDuration(double seconds) => seconds.round();

  /// Null when [seconds] fits the 1–60 s DB check.
  static String? durationError(int seconds) {
    if (seconds > maxDurationSec) {
      return 'Ringtone must be 60 seconds or shorter; trim it first.';
    }
    if (seconds < minDurationSec) {
      return 'Ringtone must be at least 1 second long.';
    }
    return null;
  }

  static String? sizeWarning(int bytes) {
    if (bytes <= sizeWarningBytes) return null;
    return 'Large file (${formatBytes(bytes)}). Ringtones should be about '
        '200–500 KB so they load fast on mobile data.';
  }

  static String? titleError(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'Title is required.';
    if (trimmed.length > maxTitleLength) return 'Title is too long.';
    return null;
  }

  static const _junkTokens = {
    'audiocutter',
    'ringtone',
    'ringtones',
    'viral',
    'mp3',
    'm4a',
    'ogg',
    'kbps',
    'download',
  };

  /// "audiocutter-ram-siya-ram-ringtone-256k-59546.mp3" → "Ram Siya Ram".
  static String titleFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final words = base
        .split(RegExp(r'[\s_\-.()\[\]]+'))
        .where((word) {
          final lower = word.toLowerCase();
          if (lower.isEmpty || _junkTokens.contains(lower)) return false;
          if (RegExp(r'^\d+$').hasMatch(lower)) return false;
          // Bitrates such as 128k, 256kbps, 320kb.
          if (RegExp(r'^\d+k(b|bps)?$').hasMatch(lower)) return false;
          return true;
        })
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .toList();
    if (words.isEmpty) return base.trim();
    return words.join(' ');
  }

  /// Trims and collapses inner whitespace.
  static String normalizeCategoryName(String raw) =>
      raw.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Null when [raw] is a valid, unique category name. [currentName] is the
  /// category being edited (it may keep its own name).
  static String? categoryNameError(
    String raw, {
    required Iterable<String> existingNames,
    String? currentName,
  }) {
    final name = normalizeCategoryName(raw);
    if (name.isEmpty) return 'Category name is required.';
    if (_reservedCategories.contains(name.toLowerCase())) {
      return 'The app adds "All" by itself; pick another name.';
    }
    if (name.length > maxCategoryLength) return 'Category name is too long.';
    final current = currentName?.toLowerCase();
    for (final existing in existingNames) {
      final value = existing.toLowerCase();
      if (value == name.toLowerCase() && value != current) {
        return 'A category with this name already exists.';
      }
    }
    return null;
  }

  /// R2 object key for a ringtone URL on media.apnipost.com, or null when
  /// the file isn't ours to delete.
  static String? objectKeyFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host != mediaHost) return null;
    final key = Uri.decodeComponent(uri.path).replaceFirst(RegExp(r'^/+'), '');
    return key.startsWith(objectPrefix) ? key : null;
  }

  /// 27 → "0:27".
  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).round()} KB';
  }
}
