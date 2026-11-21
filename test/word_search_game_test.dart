// Find the Words screen: dragging from a word's first letter to its last
// (either way) marks it and crosses it off; other drags change nothing;
// finding every word shows "All words found!".

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:lex_hopper/crossword_puzzle.dart' show WordCandidate;
import 'package:lex_hopper/word_search_game_page.dart';
import 'package:lex_hopper/word_search_puzzle.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 6×6, CAT across the top row, DOG down the last column, filler X.
WordSearchPuzzle puzzle() {
  final letters = List.filled(36, 'X');
  void put(String w, int r, int c, WordDirection d) {
    for (var i = 0; i < w.length; i++) {
      letters[(r + d.dRow * i) * 6 + c + d.dCol * i] = w[i];
    }
  }

  put('CAT', 0, 0, WordDirection.across);
  put('DOG', 1, 5, WordDirection.down);
  return WordSearchPuzzle(
    level: 1,
    size: 6,
    letters: letters,
    words: [
      HiddenWord(
        word: 'CAT',
        clue: 'a cat',
        wordTr: 'γάτα',
        row: 0,
        col: 0,
        direction: WordDirection.across,
      ),
      HiddenWord(
        word: 'DOG',
        clue: 'a dog',
        row: 1,
        col: 5,
        direction: WordDirection.down,
      ),
    ],
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: WordSearchGamePage(puzzle: puzzle(), language: 'en'),
      ),
    );
    await tester.pump();
  }

  /// Centre of square (r, c) on screen.
  Offset square(WidgetTester tester, int r, int c) {
    final grid = tester.getRect(find.byKey(const Key('ws-grid')));
    final cell = grid.width / 6;
    return grid.topLeft + Offset((c + 0.5) * cell, (r + 0.5) * cell);
  }

  Future<void> drag(WidgetTester tester, (int, int) a, (int, int) b) async {
    final from = square(tester, a.$1, a.$2);
    await tester.timedDragFrom(
      from,
      square(tester, b.$1, b.$2) - from,
      const Duration(milliseconds: 300),
    );
    await tester.pump();
  }

  bool isFound(WidgetTester tester, String word) {
    // A found word's chip takes its highlighter colour (white otherwise).
    final chip = tester.widget<Container>(find.byKey(Key('ws-word-$word')));
    final color = (chip.decoration! as BoxDecoration).color;
    return color != AppColors.gridCellLight;
  }

  testWidgets('dragging over a word finds it; a wrong drag does nothing', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('0 of 2 found'), findsOneWidget);

    // Only part of CAT: nothing.
    await drag(tester, (0, 0), (0, 1));
    expect(isFound(tester, 'CAT'), isFalse);

    // All of CAT: found.
    await drag(tester, (0, 0), (0, 2));
    expect(isFound(tester, 'CAT'), isTrue);
    expect(find.text('1 of 2 found'), findsOneWidget);
    expect(find.byKey(const Key('ws-solved')), findsNothing);
  });

  testWidgets('a word can be dragged from its last letter to its first', (
    tester,
  ) async {
    await pump(tester);
    await drag(tester, (3, 5), (1, 5));
    expect(isFound(tester, 'DOG'), isTrue);
  });

  testWidgets('a drag slightly off the line still snaps straight', (
    tester,
  ) async {
    await pump(tester);
    // From C to a bit below T: snaps to across.
    final from = square(tester, 0, 0);
    final to = square(tester, 0, 2) + const Offset(0, 20);
    await tester.timedDragFrom(
      from,
      to - from,
      const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(isFound(tester, 'CAT'), isTrue);
  });

  testWidgets('finding every word solves the level', (tester) async {
    await pump(tester);
    await drag(tester, (0, 0), (0, 2));
    await drag(tester, (1, 5), (3, 5));
    expect(find.text('2 of 2 found'), findsOneWidget);
    expect(find.byKey(const Key('ws-solved')), findsOneWidget);
    expect(find.text('All words found!'), findsOneWidget);
  });

  testWidgets('with Greek as secondary, words show their translation', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('γάτα'), findsNothing);
    await AppSettings.instance.setSecondaryLanguage('el');
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('ws-word-CAT')),
        matching: find.text('γάτα'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a found word is coloured, not struck through', (tester) async {
    await pump(tester);
    await drag(tester, (0, 0), (0, 2));
    expect(isFound(tester, 'CAT'), isTrue);
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('ws-word-CAT')),
        matching: find.text('CAT'),
      ),
    );
    expect(text.style?.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('the test button skips to the next level until solved', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const Key('ws-hint')), findsNothing);
    await tester.tap(find.byKey(const Key('ws-next-level-test')));
    await tester.pump();
    expect(find.text('Level Two'), findsOneWidget);
  });

  testWidgets('once every word is found, only Next level is offered', (
    tester,
  ) async {
    await pump(tester);
    await drag(tester, (0, 0), (0, 2));
    await drag(tester, (1, 5), (3, 5));
    expect(find.byKey(const Key('ws-next-level-test')), findsNothing);
    expect(find.byKey(const Key('ws-next-level')), findsOneWidget);
  });

  testWidgets('on a page long enough to scroll, drags still find words', (
    tester,
  ) async {
    // 12×12 with 15 words on a short screen: the page scrolls, and its
    // scrolling must not take the drag away from the grid.
    final p =
        WordSearchGenerator(
          size: 12,
          directions: WordDirection.values,
          random: Random(2),
        ).make(
          [
            for (final w in [
              'APPLE',
              'BREAD',
              'CHEESE',
              'BANANA',
              'ORANGE',
              'PIZZA',
              'SALAD',
              'BUTTER',
              'COOKIE',
              'MANGO',
              'HONEY',
              'LEMON',
              'PASTA',
              'TOAST',
              'MUFFIN',
              'STRAWBERRY',
            ])
              WordCandidate(w, w),
          ],
          level: 7,
          targetWords: 15,
        )!;
    await tester.binding.setSurfaceSize(const Size(400, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: WordSearchGamePage(puzzle: p, language: 'en'),
      ),
    );
    await tester.pump();
    final grid = tester.getRect(find.byKey(const Key('ws-grid')));
    final cell = grid.width / 12;
    Offset at((int, int) rc) =>
        grid.topLeft + Offset((rc.$2 + 0.5) * cell, (rc.$1 + 0.5) * cell);
    var found = 0;
    for (final dir in [WordDirection.across, WordDirection.down]) {
      final w = p.words.firstWhere((w) => w.direction == dir);
      await tester.timedDragFrom(
        at(w.cells.first),
        at(w.cells.last) - at(w.cells.first),
        const Duration(milliseconds: 600),
      );
      await tester.pump();
      found++;
      expect(find.text('$found of 15 found'), findsOneWidget, reason: w.word);
    }
  });
}
