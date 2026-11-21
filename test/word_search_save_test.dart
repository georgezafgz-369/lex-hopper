// Find the Words keeps its game: every found word is saved, Continue on the
// menu reopens the same grid with those words still marked, and New Game
// starts over. English and Greek games are kept apart.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:lex_hopper/word_search_game_page.dart';
import 'package:lex_hopper/word_search_menu_page.dart';
import 'package:lex_hopper/word_search_puzzle.dart';
import 'package:lex_hopper/word_search_save.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 6×6, level 4: CAT across the top row, DOG down the last column.
WordSearchPuzzle puzzle() {
  final letters = List.filled(36, 'X');
  for (var i = 0; i < 3; i++) {
    letters[i] = 'CAT'[i];
    letters[(1 + i) * 6 + 5] = 'DOG'[i];
  }
  return WordSearchPuzzle(
    level: 4,
    size: 6,
    letters: letters,
    words: [
      HiddenWord(
        word: 'CAT',
        clue: 'a cat',
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

bool isFound(WidgetTester tester, String word) {
  // A found word's chip takes its highlighter colour (white otherwise).
  final chip = tester.widget<Container>(find.byKey(Key('ws-word-$word')));
  final color = (chip.decoration! as BoxDecoration).color;
  return color != AppColors.gridCellLight;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  testWidgets('a found word is saved with the puzzle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: WordSearchGamePage(puzzle: puzzle(), language: 'en'),
      ),
    );
    await tester.pump();
    final grid = tester.getRect(find.byKey(const Key('ws-grid')));
    final cell = grid.width / 6;
    Offset at(int r, int c) =>
        grid.topLeft + Offset((c + 0.5) * cell, (r + 0.5) * cell);
    await tester.timedDragFrom(
      at(0, 0),
      at(0, 2) - at(0, 0),
      const Duration(milliseconds: 300),
    );
    await tester.pump();

    final saved = await WordSearchSave.load(language: 'en');
    expect(saved, isNotNull);
    expect(saved!.puzzle.level, 4);
    expect(saved.found.keys, ['CAT']);
    // The Greek game is separate.
    expect(await WordSearchSave.load(language: 'el'), isNull);
  });

  testWidgets('Continue reopens the saved grid with found words marked', (
    tester,
  ) async {
    await WordSearchSave.save(
      WordSearchProgress(puzzle(), {'DOG': 0}),
      language: 'en',
    );
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: WordSearchMenuPage()));
    await tester.pumpAndSettle();
    expect(find.text('Pick up where you left off — Level 4.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ws-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Level Four'), findsOneWidget);
    expect(isFound(tester, 'DOG'), isTrue);
    expect(isFound(tester, 'CAT'), isFalse);
    expect(find.text('1 of 2 found'), findsOneWidget);
  });

  testWidgets('with no save, Continue says so and does nothing', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WordSearchMenuPage()));
    await tester.pumpAndSettle();
    expect(find.text('No saved game.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ws-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(WordSearchGamePage), findsNothing);
  });
}
