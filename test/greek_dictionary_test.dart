// The Greek dictionary is searched without accents, and the right
// dictionary and voices are picked for each app language.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lex_hopper/app_text.dart';
import 'package:lex_hopper/dictionary_service.dart';
import 'package:lex_hopper/speech.dart';

void main() {
  test('greekPlain drops accents, diaeresis and capitals', () {
    expect(greekPlain('Σπίτι'), 'σπιτι');
    expect(greekPlain('ΟΔΟΣ'), 'οδοσ');
    expect(greekPlain('οδός'), 'οδοσ');
    expect(greekPlain('προϊόν'), 'προιον');
    expect(greekPlain('ταΰγετος'), 'ταυγετοσ');
    expect(greekPlain('word'), 'word');
  });

  test('each app language gets its own dictionary and voices', () {
    expect(DictionaryService.forLanguage('el'), same(DictionaryService.greek));
    expect(
      DictionaryService.forLanguage('en'),
      same(DictionaryService.english),
    );
    expect(DictionaryService.instance, same(DictionaryService.english));
    expect(Accent.forLanguage('el'), [Accent.greek]);
    expect(Accent.forLanguage('en'), [Accent.american, Accent.british]);
  });

  test('Greek has names for all 10 parts of speech', () {
    for (final pos in [
      'noun',
      'verb',
      'adj',
      'adv',
      'pron',
      'art',
      'part',
      'prep',
      'conj',
      'interj',
    ]) {
      expect(AppText.greek.partOfSpeechName(pos), isNot(pos.toUpperCase()));
    }
    expect(AppText.greek.partOfSpeechName('art'), 'Άρθρο');
    expect(AppText.greek.partOfSpeechName('part'), 'Μετοχή');
  });

  test('the two databases are bundled with the app', () {
    for (final asset in [
      DictionaryService.lexiconAsset,
      DictionaryService.textsAsset,
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
      expect(File('pubspec.yaml').readAsStringSync(), contains(asset));
    }
    // The old dictionaries are gone from the app.
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('dictionary_el.db')),
    );
  });
}
