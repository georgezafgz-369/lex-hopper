// The ☰ button on the home page opens the side menu, whose items open
// their pages.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:lex_hopper/section_icon.dart';
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
      '/games': (_) => const Scaffold(body: Text('games page')),
      '/crossword': (_) => const Scaffold(body: Text('crossword menu')),
      '/word-search': (_) => const Scaffold(body: Text('word search menu')),
      '/dictionary': (_) => const Scaffold(body: Text('dictionary page')),
      '/settings': (_) => const Scaffold(body: Text('settings page')),
    },
  );

  Future<void> openMenu(WidgetTester tester) async {
    // Tall enough for the whole menu to be built.
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    await tester.tap(find.byKey(const Key('menu-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu button sits left of the search bar', (tester) async {
    await tester.pumpWidget(app());
    final menu = tester.getCenter(find.byKey(const Key('menu-button')));
    final search = tester.getCenter(find.byKey(const Key('home-search')));
    expect(menu.dx, lessThan(search.dx));
  });

  testWidgets('each item has its coloured icon', (tester) async {
    await tester.pumpWidget(app());
    await openMenu(tester);
    for (final s in Section.values) {
      expect(
        find.byKey(Key('section-icon-${s.name}-compact')),
        findsOneWidget,
        reason: s.name,
      );
    }
  });

  testWidgets('Translator opens the translator sheet', (tester) async {
    await tester.pumpWidget(app());
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('drawer-translator')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('app-drawer')), findsNothing);
  });

  testWidgets('it opens the drawer with every item', (tester) async {
    await tester.pumpWidget(app());
    await openMenu(tester);
    final drawer = find.byKey(const Key('app-drawer'));
    expect(drawer, findsOneWidget);
    for (final label in [
      'Home',
      'Games',
      'Crossword',
      'Find the Words',
      'Riddles',
      'REFERENCE',
      'Dictionary',
      'Translator',
      'OTHER',
      'Settings',
      'Language',
    ]) {
      expect(
        find.descendant(of: drawer, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
  });

  for (final (label, page) in [
    ('Games', 'games page'),
    ('Crossword', 'crossword menu'),
    ('Find the Words', 'word search menu'),
    ('Dictionary', 'dictionary page'),
    ('Settings', 'settings page'),
  ]) {
    testWidgets('$label opens its page and closes the drawer', (tester) async {
      await tester.pumpWidget(app());
      await openMenu(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('app-drawer')),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(page), findsOneWidget);
      expect(find.byKey(const Key('app-drawer')), findsNothing);
    });
  }

  testWidgets('Home and Riddles just close the drawer / do nothing', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await openMenu(tester);
    await tester.tap(find.text('Riddles'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-drawer')), findsOneWidget); // still open

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-drawer')), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('Language opens the language list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(app());
    await openMenu(tester);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-drawer')), findsNothing);
    expect(find.byKey(const Key('language-el')), findsOneWidget);
  });
}
