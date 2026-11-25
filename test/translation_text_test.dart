import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/translation_text.dart';

void main() {
  group('cleanForTranslation', () {
    test('curly quotes, dashes and the ellipsis become plain', () {
      expect(
        cleanForTranslation(
          'Gray for \u201Ccoming soon\u201D \u2014 it\u2019s fine\u2026',
        ),
        'Gray for "coming soon" - it\'s fine...',
      );
    });

    test('invisible and non-breaking spaces, tabs and bold marks go', () {
      expect(
        cleanForTranslation('  **The\u00A0menu**\u200B  got\tlonger.  '),
        'The menu got longer.',
      );
    });

    test('the Greek question mark becomes ;', () {
      expect(cleanForTranslation('Τι κάνεις\u037E'), 'Τι κάνεις;');
    });

    test('lines are kept, without spaces at their ends', () {
      expect(cleanForTranslation('One. \r\n\n  Two.'), 'One.\n\nTwo.');
    });
  });

  group('splitSentences', () {
    test('splits at . ! ? before a capital letter', () {
      expect(splitSentences('It works. Does it? Yes! "Good," he said.'), [
        'It works.',
        'Does it?',
        'Yes!',
        '"Good," he said.',
      ]);
    });

    test('keeps abbreviations, initials and decimals inside', () {
      expect(
        splitSentences('Dr. Smith met J. Lee, e.g. at 3.5 km. Then left.'),
        ['Dr. Smith met J. Lee, e.g. at 3.5 km.', 'Then left.'],
      );
    });

    test('a lower-case word after a dot is the same sentence', () {
      expect(splitSentences('Version 2. it is.'), ['Version 2. it is.']);
    });

    test('; ends a Greek question only', () {
      expect(splitSentences('Πού είσαι; Έλα εδώ.', lang: 'el'), [
        'Πού είσαι;',
        'Έλα εδώ.',
      ]);
      expect(splitSentences('Go; Stay here.'), ['Go; Stay here.']);
    });

    test('closing quotes stay with their sentence', () {
      expect(splitSentences('He said "stop." Then he left.'), [
        'He said "stop."',
        'Then he left.',
      ]);
    });
  });

  group('translateBySentence', () {
    Future<String> upper(String s) async => '<${s.toUpperCase()}>';

    test('sends each clean sentence alone and joins them', () async {
      final sent = <String>[];
      final out = await translateBySentence(
        'The menu got longer. Nothing is \u201Ccommitted\u201D.',
        'en',
        (s) async {
          sent.add(s);
          return upper(s);
        },
      );
      expect(sent, ['The menu got longer.', 'Nothing is "committed".']);
      expect(out, '<THE MENU GOT LONGER.> <NOTHING IS "COMMITTED".>');
    });

    test('keeps lines and list markers, skips text with no words', () async {
      final out = await translateBySentence(
        'Title\n\n- one\n2. two\n...',
        'en',
        upper,
      );
      expect(out, '<TITLE>\n\n- <ONE>\n2. <TWO>\n...');
    });
  });
}
