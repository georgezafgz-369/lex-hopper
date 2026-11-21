// Typing into the crossword grid via the hidden text input.

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/crossword_game_page.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:lex_hopper/word_sheet.dart';
import 'package:lex_hopper/crossword_puzzle.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fixed 5×5 puzzle: 1A APPLE, 2D POTAO, 3A LEM.
CrosswordPuzzle testPuzzle() => CrosswordPuzzle.fromEntries(
  level: 1,
  size: 5,
  entries: [
    PuzzleEntry(
      word: 'APPLE',
      clue: 'Common red or green fruit',
      row: 0,
      col: 0,
      across: true,
    ),
    PuzzleEntry(
      word: 'POTAO',
      clue: 'Starchy tuber, missing last letter',
      row: 0,
      col: 1,
      across: false,
    ),
    PuzzleEntry(
      word: 'LEM',
      clue: 'A type of grass',
      row: 4,
      col: 2,
      across: true,
    ),
  ],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpGame(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    await tester.pumpWidget(
      MaterialApp(home: CrosswordGamePage(puzzle: testPuzzle())),
    );
  }

  // Level 1, row 0 is APPLE; the first cell carries clue number "1".
  Finder firstCell() => find.text('1').first;
  Finder input() => find.byType(TextField);

  testWidgets('typing fills the word and advances the cursor', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();

    for (final ch in 'apple'.split('')) {
      await tester.enterText(input(), '​$ch');
      await tester.pump();
    }

    // A, L, E appear once; P twice (grid cells only).
    expect(find.text('A'), findsOneWidget);
    expect(find.text('P'), findsNWidgets(2));
    expect(find.text('L'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);
  });

  testWidgets('backspace clears and steps back', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();

    await tester.enterText(input(), '​a');
    await tester.pump();
    await tester.enterText(input(), '​b');
    await tester.pump();
    expect(find.text('B'), findsOneWidget);

    // Cursor is on cell 3 (empty): backspace steps back to B and clears it.
    await tester.enterText(input(), '');
    await tester.pump();
    expect(find.text('B'), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  Future<void> typeWord(WidgetTester tester, String word) async {
    for (final ch in word.split('')) {
      await tester.enterText(input(), '​$ch');
      await tester.pump();
    }
  }

  // Check, in the pill over the selected word.
  Future<void> pressCheck(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('word-check')));
    await tester.tap(find.byKey(const Key('word-check')));
    await tester.pump();
  }

  testWidgets('Check marks the whole word correct', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'apple');
    await pressCheck(tester);

    expect(find.byIcon(Icons.check), findsNWidgets(5));
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('Check marks the whole word wrong, even right letters', (
    tester,
  ) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'appel'); // A, P, P are right; the word isn't
    await pressCheck(tester);

    expect(find.byIcon(Icons.close), findsNWidgets(5));
    expect(find.byIcon(Icons.check), findsNothing);
    await tester.pump(const Duration(seconds: 2)); // let the erase run
  });

  testWidgets('a wrong word is erased 2 seconds after Check', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'appel');
    await pressCheck(tester);

    // Just before 2 seconds: still there, marked wrong.
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byIcon(Icons.close), findsNWidgets(5));
    expect(find.text('L'), findsOneWidget);

    // After 2 seconds: the marks and the letters are gone.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.close), findsNothing);
    for (final letter in ['A', 'P', 'E', 'L']) {
      expect(find.text(letter), findsNothing, reason: letter);
    }

    // The cursor is back on the first square: typing refills the word.
    await typeWord(tester, 'apple');
    await pressCheck(tester);
    expect(find.byIcon(Icons.check), findsNWidgets(5));
  });

  testWidgets('a wrong word keeps letters solved by a crossing word', (
    tester,
  ) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'apple');
    await pressCheck(tester); // APPLE right: its P starts POTAO down

    // Type the down word wrong over the shared P.
    await tester.tap(find.text('DOWN CLUES'));
    await tester.pump();
    await tester.tap(find.text('Starchy tuber, missing last letter'));
    await tester.pump();
    await typeWord(tester, 'potax');
    await pressCheck(tester);
    expect(find.byIcon(Icons.close), findsNWidgets(5));

    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.close), findsNothing);
    // APPLE is untouched (both Ps, green); the down word's own letters
    // are erased.
    expect(find.text('P'), findsNWidgets(2));
    expect(find.byIcon(Icons.check), findsNWidgets(5));
    expect(find.text('T'), findsNothing);
    expect(find.text('X'), findsNothing);
  });

  testWidgets('typing again before the 2 seconds keeps the new letter', (
    tester,
  ) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'appel');
    await pressCheck(tester);

    // Fix the first letter right away (tap the first cell, type B).
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'b');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('B'), findsOneWidget); // retyped: kept
    expect(find.text('L'), findsNothing); // the rest: erased
  });

  testWidgets("the keyboard's ✓ key checks the word, keyboard stays open", (
    tester,
  ) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'apple');

    final field = tester.widget<TextField>(input());
    expect(field.textInputAction, TextInputAction.done);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byIcon(Icons.check), findsNWidgets(5));
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('Check does nothing until every cell has a letter', (
    tester,
  ) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'appl'); // one cell still empty
    await pressCheck(tester);

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('ACROSS / DOWN CLUES header buttons switch the list', (
    tester,
  ) async {
    await pumpGame(tester);
    expect(find.text('Common red or green fruit'), findsOneWidget);
    expect(find.text('Starchy tuber, missing last letter'), findsNothing);

    await tester.tap(find.text('DOWN CLUES'));
    await tester.pump();
    expect(find.text('Starchy tuber, missing last letter'), findsOneWidget);
    expect(find.text('Common red or green fruit'), findsNothing);

    await tester.tap(find.text('ACROSS CLUES'));
    await tester.pump();
    expect(find.text('Common red or green fruit'), findsOneWidget);
  });

  testWidgets('solving every word shows a Next level button', (tester) async {
    await pumpGame(tester);

    Future<void> solve(String header, String clue, String word) async {
      await tester.ensureVisible(find.text(header));
      await tester.tap(find.text(header));
      await tester.pump();
      await tester.tap(find.text(clue));
      await tester.pump();
      await typeWord(tester, word);
      // The last right letter of the puzzle solves it by itself, and the
      // buttons over that word go away; otherwise press Check.
      if (find.byKey(const Key('word-check')).evaluate().isNotEmpty) {
        await pressCheck(tester);
      }
    }

    await solve('ACROSS CLUES', 'Common red or green fruit', 'apple');
    await solve('DOWN CLUES', 'Starchy tuber, missing last letter', 'potao');
    expect(find.text('Next level'), findsNothing);
    await solve('ACROSS CLUES', 'A type of grass', 'lem');
    expect(find.text('Next level'), findsOneWidget);

    // It waits for the player: nothing changes on its own.
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Level One'), findsOneWidget);

    // Tapping it starts the next level (generation needs the real
    // dictionary, so in tests it stops at the loading/error screen).
    await tester.tap(find.text('Next level'));
    await tester.pump();
    expect(find.text('Level Two'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('filling every word correctly shows Next level without Check', (
    tester,
  ) async {
    await pumpGame(tester);

    Future<void> fill(String header, String clue, String word) async {
      await tester.ensureVisible(find.text(header));
      await tester.tap(find.text(header));
      await tester.pump();
      await tester.tap(find.text(clue));
      await tester.pump();
      await typeWord(tester, word);
    }

    await fill('ACROSS CLUES', 'Common red or green fruit', 'apple');
    await fill('DOWN CLUES', 'Starchy tuber, missing last letter', 'potao');
    expect(find.text('Next level'), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing); // nothing checked yet
    await fill('ACROSS CLUES', 'A type of grass', 'lem');

    expect(find.text('Next level'), findsOneWidget);
    // All 12 cells turn green.
    expect(find.byIcon(Icons.check), findsNWidgets(12));
  });

  testWidgets('non-letters are ignored', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();

    await tester.enterText(input(), '​7');
    await tester.pump();
    expect(find.text('7'), findsNothing);
  });

  testWidgets('one tap on a clue selects it; a double tap opens the keyboard', (
    tester,
  ) async {
    await pumpGame(tester);
    bool keyboardFocused() =>
        tester.widget<TextField>(input()).focusNode!.hasFocus;

    await tester.tap(find.text('Common red or green fruit'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(keyboardFocused(), isFalse);

    await tester.tap(find.text('Common red or green fruit'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Common red or green fruit'));
    await tester.pump();
    expect(keyboardFocused(), isTrue);

    // With the keyboard open, one tap on another clue closes it.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('A type of grass'));
    await tester.pump();
    expect(keyboardFocused(), isFalse);
  });

  testWidgets('tapping a grid cell opens the keyboard', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    expect(tester.widget<TextField>(input()).focusNode!.hasFocus, isTrue);
  });

  testWidgets('a checked word shows an ANSWER button after its clue', (
    tester,
  ) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'apple');

    // Typed but not checked yet: the answer stays hidden.
    expect(find.byKey(const Key('answer-APPLE')), findsNothing);

    await pressCheck(tester);
    expect(find.byKey(const Key('answer-APPLE')), findsOneWidget);
    // It's a button showing the word, without brackets.
    expect(
      find.descendant(
        of: find.byKey(const Key('answer-APPLE')),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
    expect(find.text('APPLE'), findsWidgets);
    expect(find.text('[APPLE]'), findsNothing);
    // Words that weren't checked stay hidden.
    expect(find.byKey(const Key('answer-LEM')), findsNothing);

    // Pressing it opens the word's page.
    await tester.ensureVisible(find.byKey(const Key('answer-APPLE')));
    await tester.tap(find.byKey(const Key('answer-APPLE')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(WordDetailPage), findsOneWidget);
  });

  testWidgets('a wrong word shows no answer', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'apply');
    await pressCheck(tester);
    expect(find.byKey(const Key('answer-APPLE')), findsNothing);
  });

  testWidgets('the big Clear / Hint / Check buttons are gone', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    // Only the pill over the word has them.
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Hint, please'), findsNothing);
    // Clear is black with white letters.
    final clear = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('word-clear')),
        matching: find.text('Clear'),
      ),
    );
    expect(clear.style!.color, Colors.white);
    final fill = tester.widget<Material>(
      find
          .ancestor(
            of: find.byKey(const Key('word-clear')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(fill.color, AppColors.inkLight);
    for (final key in ['word-clear', 'word-hint', 'word-check']) {
      expect(
        find.descendant(
          of: find.byKey(const Key('word-tools')),
          matching: find.byKey(Key(key)),
        ),
        findsOneWidget,
        reason: key,
      );
    }
  });

  testWidgets('Search on dictionary sits in the top bar', (tester) async {
    await pumpGame(tester);
    final search = tester.getCenter(find.text('Search on dictionary'));
    final level = tester.getCenter(find.text('Level One'));
    expect((search.dy - level.dy).abs(), lessThan(10)); // same row
  });

  testWidgets('the test button skips to the next level unsolved', (
    tester,
  ) async {
    await pumpGame(tester);
    expect(find.text('Level One'), findsOneWidget);
    await tester.ensureVisible(find.text('Next level (test)'));
    await tester.tap(find.text('Next level (test)'));
    await tester.pump();
    expect(find.text('Level Two'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a phrase answer draws its space as a black square', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    final puzzle = CrosswordPuzzle.fromEntries(
      level: 5,
      size: 7,
      entries: [
        PuzzleEntry(
          word: 'GIVE#UP',
          clue: 'Stop trying',
          row: 0,
          col: 0,
          across: true,
        ),
        PuzzleEntry(word: 'GET', clue: 'Obtain', row: 0, col: 0, across: false),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(home: CrosswordGamePage(puzzle: puzzle)),
    );
    expect(find.byKey(const Key('gap-0-4')), findsOneWidget);

    // Typing the phrase skips the black square.
    await tester.tap(find.text('Stop trying'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Stop trying'));
    await tester.pump();
    await typeWord(tester, 'giveup');
    expect(find.text('U'), findsOneWidget);
    expect(find.text('P'), findsOneWidget);

    await pressCheck(tester);
    expect(find.byKey(const Key('answer-GIVE UP')), findsOneWidget);
  });

  // ── Clear / Hint over the selected word ──────────────────────────────

  Finder tools() => find.byKey(const Key('word-tools'));

  testWidgets('the word tools float above the word, below on the top row', (
    tester,
  ) async {
    await pumpGame(tester);
    // APPLE starts on the top row: the tools sit below it.
    await tester.tap(firstCell());
    await tester.pump();
    expect(tools(), findsOneWidget);
    final apple = tester.getRect(find.text('1').first);
    expect(tester.getRect(tools()).top, greaterThan(apple.bottom));

    // LEM is on row 4: the tools sit just above it.
    await tester.tap(find.text('A type of grass'));
    await tester.pump(const Duration(milliseconds: 500));
    final lem = tester.getRect(find.text('3').first);
    final rect = tester.getRect(tools());
    expect(rect.bottom, lessThanOrEqualTo(lem.top));
    // Lined up with the word, or shifted left just enough to stay inside
    // the grid (LEM ends at the right edge).
    expect(rect.left, lessThanOrEqualTo(lem.left));
    expect(rect.right, lessThanOrEqualTo(400)); // inside the screen
  });

  testWidgets('Clear (one tap) empties the word; Hint gives a letter', (
    tester,
  ) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'xyz');
    expect(find.text('X'), findsOneWidget);

    await tester.tap(find.byKey(const Key('word-clear')));
    await tester.pump();
    for (final l in ['X', 'Y', 'Z']) {
      expect(find.text(l), findsNothing, reason: l);
    }

    await tester.tap(find.byKey(const Key('word-hint')));
    await tester.pump();
    expect(find.text('A'), findsOneWidget); // APPLE's first letter
  });

  testWidgets('Clear keeps letters of a solved crossing word', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    await typeWord(tester, 'apple');
    await pressCheck(tester);

    await tester.tap(find.text('DOWN CLUES'));
    await tester.pump();
    await tester.tap(find.text('Starchy tuber, missing last letter'));
    await tester.pump(const Duration(milliseconds: 500));
    await typeWord(tester, 'potax');
    await tester.tap(find.byKey(const Key('word-clear')));
    await tester.pump();

    expect(find.text('P'), findsNWidgets(2)); // APPLE untouched
    expect(find.byIcon(Icons.check), findsNWidgets(5));
    expect(find.text('T'), findsNothing);
  });

  testWidgets('a solved word shows no tools', (tester) async {
    await pumpGame(tester);
    await tester.tap(firstCell());
    await tester.pump();
    expect(tools(), findsOneWidget);
    await typeWord(tester, 'apple');
    await pressCheck(tester);
    // The cursor may move on; select APPLE again.
    await tester.tap(firstCell());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tools(), findsNothing);
  });
}
