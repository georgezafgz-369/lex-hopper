// The round button over every page opens a menu of the sections; a tap
// outside, the button again, or Back closes it, a row opens its page. It
// shrinks while open, can be dragged, and hides under sheets.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/sections_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SectionsButton.place = null;
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Widget page(String name) => Scaffold(body: Center(child: Text('$name page')));

  Widget app() {
    final navigator = GlobalKey<NavigatorState>();
    return MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [SectionsButton.observer],
      builder: (context, child) => Stack(
        children: [
          child!,
          Positioned.fill(child: SectionsButton(navigator: navigator)),
        ],
      ),
      routes: {
        '/': (_) => page('home'),
        '/games': (_) => page('games'),
        '/dictionary': (_) => page('dictionary'),
        '/translator': (_) => page('translator'),
        '/chat': (_) => page('chat'),
        '/settings': (_) => page('settings'),
      },
    );
  }

  final button = find.byKey(const Key('sections-button'));
  final menu = find.byKey(const Key('sections-menu'));

  Future<void> open(WidgetTester tester) async {
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('sits at the bottom right above page bars, round and small', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    final rect = tester.getRect(button);
    expect(rect.width, rect.height);
    expect(rect.width, lessThanOrEqualTo(52));
    expect(rect.right, greaterThan(400 - 40));
    expect(rect.bottom, greaterThan(800 - 140));
    expect(rect.bottom, lessThan(800 - 72));
  });

  testWidgets('menu: Home first, then the sections', (tester) async {
    await tester.pumpWidget(app());
    expect(menu, findsNothing);
    await open(tester);
    expect(menu, findsOneWidget);
    double? last;
    for (final k in [
      'home',
      'games',
      'dictionary',
      'translator',
      'chat',
      'settings',
    ]) {
      final top = tester.getRect(find.byKey(Key('sections-$k'))).top;
      if (last != null) expect(top, greaterThan(last));
      last = top;
    }
  });

  testWidgets('closes on a tap outside, the button, and Back', (tester) async {
    await tester.pumpWidget(app());
    await open(tester);
    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(menu, findsNothing);

    await open(tester);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(menu, findsNothing);

    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(menu, findsNothing);
    expect(find.text('home page'), findsOneWidget);
  });

  testWidgets('on every page; a row opens its page over home', (tester) async {
    await tester.pumpWidget(app());
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-games')));
    await tester.pumpAndSettle();
    expect(find.text('games page'), findsOneWidget);
    expect(menu, findsNothing);

    // Still there on the games page; from there to the dictionary.
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-dictionary')));
    await tester.pumpAndSettle();
    expect(find.text('dictionary page'), findsOneWidget);

    // Back goes home (the games page isn't kept under it).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sections-chat')));
    await tester.pumpAndSettle();
    await open(tester);
    await tester.tap(find.byKey(const Key('sections-home')));
    await tester.pumpAndSettle();
    expect(find.text('home page'), findsOneWidget);
    expect(find.text('chat page'), findsNothing);
  });

  testWidgets('shrinks while the menu is open', (tester) async {
    await tester.pumpWidget(app());
    final closed = tester.getRect(button).width;
    await open(tester);
    expect(tester.getRect(button).width, lessThan(closed * 0.85));
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.getRect(button).width, closed);
  });

  testWidgets('dragged to the top left, the menu opens below it', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.drag(button, const Offset(-600, -900));
    await tester.pumpAndSettle();
    final at = tester.getRect(button);
    expect(at.left, lessThan(40));
    expect(at.top, lessThan(80));

    await open(tester);
    final rect = tester.getRect(menu);
    expect(rect.top, greaterThan(at.bottom));
    expect(rect.left, closeTo(at.left, 1));
  });

  testWidgets('hides while a sheet is up', (tester) async {
    await tester.pumpWidget(app());
    showModalBottomSheet<void>(
      context: tester.element(find.text('home page')),
      builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
    );
    await tester.pumpAndSettle();
    expect(button, findsNothing);
    Navigator.of(tester.element(find.text('sheet'))).pop();
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);
  });
}
