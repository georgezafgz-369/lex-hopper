// The Find the Words and Crossword menus have the dictionary search bar in
// their top bar, between Back and Home, and it looks words up like the one
// on home.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/crossword_menu_page.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:lex_hopper/dictionary_page.dart';
import 'package:lex_hopper/word_search_menu_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  for (final (name, page, back, search) in [
    (
      'Find the Words',
      const WordSearchMenuPage(),
      'word-search-menu-back',
      'word-search-menu-search',
    ),
    (
      'Crossword',
      const CrosswordMenuPage(),
      'crossword-menu-back',
      'crossword-menu-search',
    ),
  ]) {
    testWidgets('$name menu: search bar between Back and Home, searches', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();

      final field = find.byKey(Key(search));
      expect(field, findsOneWidget);
      final backAt = tester.getCenter(find.byKey(Key(back)));
      final searchAt = tester.getCenter(field);
      final homeAt = tester.getCenter(find.byType(HomeButton));
      expect(searchAt.dx, greaterThan(backAt.dx));
      expect(searchAt.dx, lessThan(homeAt.dx));
      expect((searchAt.dy - backAt.dy).abs(), lessThan(4)); // same row

      await tester.enterText(field, 'cat');
      await tester.tap(find.byKey(const Key('search-icon')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final dictionary = tester.widget<DictionaryPage>(
        find.byType(DictionaryPage),
      );
      expect(dictionary.initialQuery, 'cat');
    });
  }
}
