// Suggestions while typing in the dictionary search: from the dictionary
// of the letters' alphabet, else the app's language, the secondary one and
// English.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/dictionary_search_bar.dart';

void main() {
  test('Greek and Cyrillic letters pick their dictionary', () {
    expect(suggestionDictionaries('καλη', main: 'en'), ['el']);
    expect(suggestionDictionaries('дом', main: 'en', second: 'el'), ['ru']);
  });

  test('Latin letters: the app language, the secondary one, then English', () {
    expect(suggestionDictionaries('ca', main: 'fr', second: 'es'), [
      'fr',
      'es',
      'en',
    ]);
    // Greek or Russian as app language don't read Latin letters.
    expect(suggestionDictionaries('ca', main: 'el', second: 'ru'), ['en']);
    expect(suggestionDictionaries('ca', main: 'en'), ['en']);
  });
}
