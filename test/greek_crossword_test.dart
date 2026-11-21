// Greek crosswords: Greek letters typed with or without accents fill the
// grid as capitals without accents, each language keeps its own saved game,
// and the Greek dictionary has enough answers to build every level.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'lexicon_sql.dart';

import 'package:lex_hopper/crossword_game_page.dart';
import 'package:lex_hopper/crossword_puzzle.dart';
import 'package:lex_hopper/crossword_save.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1A ΣΠΙΤΙ, 2D ΠΑΙΔΙ (crossing at Π).
CrosswordPuzzle greekPuzzle() => CrosswordPuzzle.fromEntries(
  level: 1,
  size: 5,
  entries: [
    PuzzleEntry(
      word: 'ΣΠΙΤΙ',
      clue: 'Κτίσμα που χρησιμοποιείται ως κατοικία',
      row: 0,
      col: 0,
      across: true,
    ),
    PuzzleEntry(
      word: 'ΠΑΙΔΙ',
      clue: 'Νεαρό άτομο',
      row: 0,
      col: 1,
      across: false,
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpGreekGame(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    await tester.pumpWidget(
      MaterialApp(
        home: CrosswordGamePage(puzzle: greekPuzzle(), language: 'el'),
      ),
    );
    await tester.tap(find.text('1').first);
    await tester.pump();
  }

  Finder input() => find.byType(TextField);

  testWidgets('Greek letters fill the grid as capitals without accents', (
    tester,
  ) async {
    await pumpGreekGame(tester);
    for (final ch in 'σπίτι'.split('')) {
      await tester.enterText(input(), '​$ch');
      await tester.pump();
    }
    expect(find.text('Σ'), findsOneWidget);
    expect(find.text('Π'), findsOneWidget);
    expect(find.text('Ι'), findsNWidgets(2));
    expect(find.text('Τ'), findsOneWidget);
    expect(find.text('Ί'), findsNothing);
  });

  testWidgets('a Greek game ignores Latin letters and uses the text keyboard', (
    tester,
  ) async {
    await pumpGreekGame(tester);
    await tester.enterText(input(), '​a');
    await tester.pump();
    expect(find.text('A'), findsNothing);
    final field = tester.widget<TextField>(input());
    expect(field.keyboardType, TextInputType.text);
  });

  test('English and Greek games are saved apart', () async {
    await CrosswordSave.save({'currentLevel': 3}, language: 'el');
    expect(await CrosswordSave.load(language: 'en'), isNull);
    expect((await CrosswordSave.load(language: 'el'))!['currentLevel'], 3);
  });

  test('Greek levels fit the smaller word list', () {
    final one = LevelSettings.forLevel(1, poolSize: 5000);
    expect(one.maxRank, 1000);
    expect(one.minRank, 1);
    for (var level = 2; level <= 60; level++) {
      final s = LevelSettings.forLevel(level, poolSize: 5000);
      expect(s.maxRank, lessThanOrEqualTo(5000));
      expect(s.minRank, lessThan(s.maxRank));
    }
    // English is unchanged.
    expect(LevelSettings.forLevel(3).maxRank, 6000);
    expect(LevelSettings.forLevel(3).minRank, 1500);
  });

  test('every Greek level can be built from the Greek dictionary', () {
    final out = puzzleSql(
      'el',
      'SELECT word, len, rank, clue, phrase FROM puzzle_words',
    );
    final rows = [for (final line in out.split('\n')) line.split('\t')];
    final pool = rows
        .where((r) => r[4] == '0')
        .map((r) => int.parse(r[2]))
        .reduce(max);
    for (final level in [1, 2, 3, 4, 5, 8, 20]) {
      final s = LevelSettings.forLevel(level, poolSize: pool);
      final candidates = [
        for (final r in rows)
          if (int.parse(r[1]) >= s.minLen &&
              int.parse(r[1]) <= s.maxLen &&
              int.parse(r[2]) <= s.maxRank &&
              (r[4] == '1' ? s.phrases : int.parse(r[2]) >= s.minRank))
            WordCandidate(r[0].replaceAll(' ', phraseGap), r[3]),
      ]..shuffle(Random(level));
      final entries =
          CrosswordGenerator(size: s.gridSize, random: Random(level)).layout(
            candidates.take(400).toList(),
            targetWords: s.targetWords,
            minWords: min(3, s.targetWords),
          );
      expect(entries, isNotNull, reason: 'level $level');
      expect(
        entries!.every((e) => RegExp(r'^[Α-Ω#]+$').hasMatch(e.word)),
        isTrue,
        reason: 'answers are Greek capitals without accents',
      );
    }
  });
}
