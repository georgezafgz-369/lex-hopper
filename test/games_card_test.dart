// The home page shows all games as one card; tapping it opens the Games
// page, which lists each game and opens it.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:lex_hopper/dictionary_page.dart';
import 'package:lex_hopper/games_page.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Widget app() => MaterialApp(
    routes: {
      '/': (_) => const HomePage(),
      '/games': (_) => const GamesPage(),
      '/crossword': (_) => const Scaffold(body: Text('crossword menu')),
    },
  );

  testWidgets('home lists the games on one card, which opens the Games page', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    // One card naming every game; no separate game cards on home.
    expect(find.text('Crossword · Find the Words · Riddles'), findsOneWidget);
    expect(find.text('Crossword'), findsNothing);

    await tester.tap(find.byKey(const Key('games-card')));
    await tester.pumpAndSettle();
    expect(find.byType(GamesPage), findsOneWidget);
    expect(find.text('Crossword'), findsOneWidget);
    expect(find.text('Find the Words'), findsOneWidget);
    expect(find.text('Riddles'), findsOneWidget);

    // A game opens from there.
    await tester.tap(find.text('Crossword'));
    await tester.pumpAndSettle();
    expect(find.text('crossword menu'), findsOneWidget);
  });

  testWidgets('back on the Games page returns home', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('games-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('games-back')));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('the Games page search bar opens the dictionary', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('games-card')));
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('games-search'));
    expect(field, findsOneWidget);
    // It sits between the back and home buttons.
    final back = tester.getCenter(find.byKey(const Key('games-back')));
    final search = tester.getCenter(field);
    final home = tester.getCenter(find.byType(HomeButton));
    expect(search.dx, greaterThan(back.dx));
    expect(search.dx, lessThan(home.dx));

    await tester.enterText(field, 'apple');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DictionaryPage), findsOneWidget);
  });
}
