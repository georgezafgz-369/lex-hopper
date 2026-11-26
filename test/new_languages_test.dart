// Italian, French and Russian: the app's own text, Russian plurals and
// alphabet, and which dictionary and voice a word goes to.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/ai_model.dart';
import 'package:lex_hopper/app_text.dart';
import 'package:lex_hopper/chat_page.dart';
import 'package:lex_hopper/dictionary_service.dart';
import 'package:lex_hopper/speech.dart';
import 'package:lex_hopper/word_look_up.dart';

void main() {
  test('the app speaks Italian, French and Russian', () {
    expect(AppText.forCode('it').dictionary, 'Dizionario');
    expect(AppText.forCode('fr').dictionary, 'Dictionnaire');
    expect(AppText.forCode('ru').dictionary, 'Словарь');
    expect(AppText.forCode('ru').languageName('ru'), 'Русский');
    expect(AppText.forCode('el').languageName('ru'), 'Ρωσικά');
    expect(AppText.forCode('fr').partOfSpeechName('noun'), 'Nom');
  });

  test('Russian counts take the right plural', () {
    final ru = AppText.forCode('ru');
    expect(ru.meanings(1), '1 значение');
    expect(ru.meanings(3), '3 значения');
    expect(ru.meanings(5), '5 значений');
    expect(ru.meanings(11), '11 значений');
    expect(ru.meanings(21), '21 значение');
    expect(ru.wordCount(1234), '1 234 слова');
  });

  test('dates in the new languages', () {
    final d = DateTime(2026, 11, 25); // a Wednesday
    expect(AppText.forCode('it').shortDate(d), 'mer 25 nov');
    expect(AppText.forCode('fr').shortDate(d), 'mer. 25 nov.');
    expect(AppText.forCode('ru').shortDate(d), 'ср 25 нояб.');
  });

  test('voices and the Russian search key', () {
    expect(Accent.forLanguage('it'), [Accent.italian]);
    expect(Accent.forLanguage('fr'), [Accent.french]);
    expect(Accent.forLanguage('ru'), [Accent.russian]);
    expect(latinPlain('Ёлка'), 'елка');
  });

  test('a Cyrillic word is looked up in Russian', () {
    expect(WordLookUp.dictionariesFor('собака', main: 'en', second: 'it'), [
      'ru',
    ]);
    expect(WordLookUp.dictionariesFor('cane', main: 'ru', second: 'it'), [
      'it',
      'en',
    ]);
  });

  test('reading aloud keeps the Russian part', () {
    expect(
      speakablePart(
        'Собака лает. (The dog barks.)',
        language: 'ru',
        main: 'en',
      ),
      'Собака лает.',
    );
    expect(AiModel.isInLanguage('Собака лает', 'ru'), isTrue);
    expect(AiModel.isInLanguage('The dog barks', 'ru'), isFalse);
    expect(AiModel.isInLanguage('Il cane abbaia', 'it'), isTrue);
  });
}
