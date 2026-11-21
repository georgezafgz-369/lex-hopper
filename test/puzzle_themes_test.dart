// Subjects for new games: the dictionaries only use the app's theme ids,
// levels move from a theme's common words to its rarer ones, every theme
// offered in a language can fill each kind of level in both games, and a
// game keeps its subject when saved.

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'lexicon_sql.dart';

import 'package:lex_hopper/crossword_puzzle.dart';
import 'package:lex_hopper/puzzle_themes.dart';
import 'package:lex_hopper/theme_picker.dart';
import 'package:lex_hopper/word_search_puzzle.dart';
import 'package:lex_hopper/word_search_save.dart';

List<List<String>> themeRows(String lang, PuzzleTheme t) {
  final out = puzzleSql(
    lang,
    'SELECT word, len, clue FROM puzzle_words '
    "WHERE phrase = 0 AND theme = '${t.id}' ORDER BY rank",
  );
  return [
    for (final l in out.split('\n'))
      if (l.contains('\t')) l.split('\t'),
  ];
}

List<WordCandidate> candidates(
  List<List<String>> rows,
  int level,
  int minLen,
  int maxLen,
  Random random,
) {
  final (start, end) = themeWindow(level, rows.length);
  return ([
    for (final r in rows.sublist(start, end))
      if (int.parse(r[1]) >= minLen && int.parse(r[1]) <= maxLen)
        WordCandidate(r[0], r[2]),
  ]..shuffle(random)).take(400).toList();
}

void main() {
  test('the dictionaries only use the app\'s theme ids', () {
    final ids = {for (final t in puzzleThemes) t.id};
    for (final db in ['en', 'el']) {
      final out = puzzleSql(
        db,
        'SELECT DISTINCT theme FROM puzzle_words WHERE theme IS NOT NULL',
      );
      for (final id in out.split('\n')) {
        expect(ids, contains(id), reason: '$db: $id');
      }
    }
    expect(PuzzleTheme.byId('animals')!.nameEl, 'Ζώα');
    expect(PuzzleTheme.byId(null), isNull);
  });

  test('levels go from a theme\'s common words to its rarer ones', () {
    expect(themeWindow(1, 2000), (0, 250));
    expect(themeWindow(2, 2000), (0, 500));
    expect(themeWindow(4, 2000), (500, 2000));
    expect(themeWindow(9, 2000), (500, 2000));
    // A small theme uses all its words from the start.
    expect(themeWindow(1, 90), (0, 90));
  });

  test('a saved Find the Words game keeps its subject', () {
    final p = WordSearchPuzzle(
      level: 3,
      size: 6,
      letters: List.filled(36, 'A'),
      words: [
        HiddenWord(
          word: 'AAA',
          clue: 'a',
          row: 0,
          col: 0,
          direction: WordDirection.across,
        ),
      ],
    );
    final music = PuzzleTheme.byId('music');
    final back = WordSearchProgress.fromJson(
      jsonDecode(jsonEncode(WordSearchProgress(p, {}, music).toJson())),
    );
    expect(back.theme, music);
    final none = WordSearchProgress.fromJson(
      jsonDecode(jsonEncode(WordSearchProgress(p, {}).toJson())),
    );
    expect(none.theme, isNull);
  });

  for (final (lang, db, alphabet, offered) in [
    ('English', 'en', englishAlphabet, 18),
    ('Greek', 'el', greekAlphabet, 9),
  ]) {
    test('$lang: every offered theme fills each kind of level', () {
      var shown = 0;
      for (final t in puzzleThemes) {
        final rows = themeRows(db, t);
        if (rows.length < minThemeWords) continue;
        shown++;
        for (final level in [1, 5, 9]) {
          final random = Random(level);
          final cw = LevelSettings.forLevel(level);
          final entries = CrosswordGenerator(size: cw.gridSize, random: random)
              .layout(
                candidates(rows, level, cw.minLen, cw.maxLen, random),
                targetWords: cw.targetWords,
                timeLimit: const Duration(milliseconds: 600),
              );
          expect(
            entries!.length,
            greaterThanOrEqualTo((cw.targetWords * 0.7).floor()),
            reason: '$lang ${t.id} crossword level $level',
          );
          final ws = WordSearchLevel.forLevel(level);
          final puzzle =
              WordSearchGenerator(
                size: ws.gridSize,
                directions: ws.directions,
                alphabet: alphabet,
                random: random,
              ).make(
                candidates(rows, level, ws.minLen, ws.maxLen, random),
                level: level,
                targetWords: ws.targetWords,
              );
          expect(
            puzzle!.words.length,
            ws.targetWords,
            reason: '$lang ${t.id} word search level $level',
          );
        }
      }
      expect(shown, offered);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
