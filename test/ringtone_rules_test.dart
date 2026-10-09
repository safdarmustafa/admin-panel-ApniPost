import 'package:apnipost_admin/features/ringtones/domain/ringtone_category.dart';
import 'package:apnipost_admin/features/ringtones/domain/ringtone_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RingtoneRules.contentTypeFor', () {
    test('maps by extension first', () {
      expect(RingtoneRules.contentTypeFor('a.mp3', ''), 'audio/mpeg');
      expect(RingtoneRules.contentTypeFor('a.M4A', 'audio/x-m4a'), 'audio/mp4');
      expect(RingtoneRules.contentTypeFor('a.ogg', ''), 'audio/ogg');
    });

    test('falls back to the browser MIME type', () {
      expect(RingtoneRules.contentTypeFor('tune', 'audio/mpeg'), 'audio/mpeg');
      expect(RingtoneRules.contentTypeFor('tune', 'audio/x-m4a'), 'audio/mp4');
    });

    test('rejects other files', () {
      expect(RingtoneRules.contentTypeFor('a.wav', 'audio/wav'), isNull);
      expect(RingtoneRules.contentTypeFor('a.mp4', 'video/mp4'), isNull);
    });
  });

  group('duration', () {
    test('rounds like Math.round', () {
      expect(RingtoneRules.roundDuration(27.4), 27);
      expect(RingtoneRules.roundDuration(60.4), 60);
      expect(RingtoneRules.roundDuration(60.5), 61);
    });

    test('allows 1–60 seconds only', () {
      expect(RingtoneRules.durationError(1), isNull);
      expect(RingtoneRules.durationError(60), isNull);
      expect(
        RingtoneRules.durationError(61),
        'Ringtone must be 60 seconds or shorter; trim it first.',
      );
      expect(RingtoneRules.durationError(0), isNotNull);
    });

    test('formats as m:ss', () {
      expect(RingtoneRules.formatDuration(7), '0:07');
      expect(RingtoneRules.formatDuration(60), '1:00');
    });
  });

  test('warns above 1 MB', () {
    expect(RingtoneRules.sizeWarning(500 * 1024), isNull);
    expect(RingtoneRules.sizeWarning(1024 * 1024 + 1), isNotNull);
  });

  group('titleFromFileName', () {
    test('cleans common download names', () {
      expect(
        RingtoneRules.titleFromFileName(
          'audiocutter-ram-siya-ram-ringtone-viral-shri-ram-ringtone-256k-59546.mp3',
        ),
        'Ram Siya Ram Shri Ram',
      );
      expect(
        RingtoneRules.titleFromFileName('durga-puja-ringtone-by-lobh-42083.mp3'),
        'Durga Puja By Lobh',
      );
      expect(
        RingtoneRules.titleFromFileName('jai_ganesh_deva (128kbps).mp3'),
        'Jai Ganesh Deva',
      );
    });

    test('keeps the name when nothing useful is left', () {
      expect(RingtoneRules.titleFromFileName('12345.mp3'), '12345');
    });
  });

  group('category names', () {
    const existing = ['Durga', 'Ganesha'];

    test('normalizes whitespace', () {
      expect(
        RingtoneRules.normalizeCategoryName('  Bhojpuri   Hits '),
        'Bhojpuri Hits',
      );
    });

    test('accepts a new unique name', () {
      expect(
        RingtoneRules.categoryNameError('Bhojpuri', existingNames: existing),
        isNull,
      );
    });

    test('rejects duplicates case-insensitively', () {
      expect(
        RingtoneRules.categoryNameError(' ganesha ', existingNames: existing),
        isNotNull,
      );
    });

    test('lets a category keep its own name while editing', () {
      expect(
        RingtoneRules.categoryNameError(
          'durga',
          existingNames: existing,
          currentName: 'Durga',
        ),
        isNull,
      );
    });

    test('rejects All, सभी and empty names', () {
      for (final name in ['all', 'ALL', 'सभी', '   ']) {
        expect(
          RingtoneRules.categoryNameError(name, existingNames: existing),
          isNotNull,
          reason: name,
        );
      }
    });
  });

  test('category label shows the Hindi name', () {
    expect(
      RingtoneCategory.fromMap({
        'id': '1',
        'name': 'Durga',
        'hindi_name': 'दुर्गा',
        'display_order': 0,
        'ringtones': [
          {'count': 3},
        ],
      }),
      isA<RingtoneCategory>()
          .having((c) => c.label, 'label', 'Durga · दुर्गा')
          .having((c) => c.ringtoneCount, 'ringtoneCount', 3),
    );
    expect(
      RingtoneCategory.fromMap({'id': '2', 'name': 'Bhojpuri'}).label,
      'Bhojpuri',
    );
  });

  test('objectKeyFromUrl only returns our ringtone keys', () {
    expect(
      RingtoneRules.objectKeyFromUrl(
        'https://media.apnipost.com/ringtones/durga/durga-puja-ringtone-by-lobh-42083.mp3',
      ),
      'ringtones/durga/durga-puja-ringtone-by-lobh-42083.mp3',
    );
    expect(
      RingtoneRules.objectKeyFromUrl(
        'https://media.apnipost.com/bhakti/20261008_x.mp4',
      ),
      isNull,
    );
    expect(
      RingtoneRules.objectKeyFromUrl('https://example.com/ringtones/a/b.mp3'),
      isNull,
    );
  });
}
