// Crosswords and word searches in the downloaded languages: typed letters
// become the answers' capitals without accents (Spanish keeps Ñ, Russian
// Ё is Е), and each language fills its word search with its own letters.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/crossword_puzzle.dart';
import 'package:lex_hopper/word_search_puzzle.dart';

void main() {
  test('Russian letters, Ё as Е; Latin letters are not Russian', () {
    expect(crosswordLetter('д', 'ru'), 'Д');
    expect(crosswordLetter('ё', 'ru'), 'Е');
    expect(crosswordLetter('Я', 'ru'), 'Я');
    expect(crosswordLetter('a', 'ru'), isNull);
  });

  test('accents go; Spanish keeps Ñ', () {
    expect(crosswordLetter('é', 'fr'), 'E');
    expect(crosswordLetter('ç', 'fr'), 'C');
    expect(crosswordLetter('ü', 'de'), 'U');
    expect(crosswordLetter('à', 'it'), 'A');
    expect(crosswordLetter('ñ', 'es'), 'Ñ');
    expect(crosswordLetter('á', 'es'), 'A');
    expect(crosswordLetter('ñ', 'fr'), 'N');
    expect(crosswordLetter('x', 'en'), 'X');
    expect(crosswordLetter('1', 'en'), isNull);
    expect(crosswordLetter('д', 'fr'), isNull);
  });

  test('each language fills its word search with its own letters', () {
    expect(alphabetFor('ru'), contains('Ж'));
    expect(alphabetFor('es'), contains('Ñ'));
    expect(alphabetFor('el'), greekAlphabet);
    expect(alphabetFor('fr'), englishAlphabet);
  });
}
