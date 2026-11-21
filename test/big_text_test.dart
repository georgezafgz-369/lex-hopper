// With large text (a big phone text size times the app's Large setting) on
// a narrow phone, and a secondary language that adds translations, pages
// must fit: no "overflowed" stripes.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/crossword_game_page.dart';
import 'package:lex_hopper/crossword_menu_page.dart';
import 'package:lex_hopper/crossword_puzzle.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:lex_hopper/settings_page.dart';
import 'package:lex_hopper/word_search_game_page.dart';
import 'package:lex_hopper/word_search_puzzle.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

CrosswordPuzzle puzzle(int size) => CrosswordPuzzle.fromEntries(
  level: 9,
  size: size,
  entries: [
    PuzzleEntry(
      word: 'ABCDEFGHIJKLM'.substring(0, size),
      clue: 'A clue that is long enough to wrap onto a second line here',
      clueTr: 'Μια μεγάλη ελληνική μετάφραση της ένδειξης για δοκιμή',
      row: 0,
      col: 0,
      across: true,
    ),
    PuzzleEntry(
      word: 'MNOPQRSTUVWXY'.substring(0, size),
      clue: 'Right column',
      row: 0,
      col: size - 1,
      across: false,
    ),
  ],
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: page,
      ),
    );
    await AppSettings.instance.setSecondaryLanguage('el');
    await tester.pump();
    await tester.pump();
  }

  final pages = <String, Widget Function()>{
    'home': () => const HomePage(),
    'settings': () => const SettingsPage(),
    'crossword menu': () => const CrosswordMenuPage(),
    'crossword game 7×7': () => CrosswordGamePage(puzzle: puzzle(7)),
    'crossword game 13×13': () => CrosswordGamePage(puzzle: puzzle(13)),
    'find the words 12×12': () => WordSearchGamePage(
      language: 'en',
      puzzle: WordSearchGenerator(size: 12, directions: WordDirection.values)
          .make(
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
          ),
    ),
  };

  for (final entry in pages.entries) {
    testWidgets('${entry.key} fits with large text', (tester) async {
      await pumpPage(tester, entry.value());
      expect(tester.takeException(), isNull);
    });
  }
}
