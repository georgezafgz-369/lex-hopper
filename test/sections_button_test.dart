// The round button at the bottom right of the home page opens a menu of
// the sections; a tap outside or Back closes it, a row opens its page.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
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
      '/settings': (_) => const Scaffold(body: Text('settings page')),
    },
  );

  testWidgets('sits at the bottom right, round', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    final rect = tester.getRect(find.byKey(const Key('sections-button')));
    expect(rect.width, rect.height);
    expect(rect.right, greaterThan(400 - 40));
    expect(rect.bottom, greaterThan(800 - 40));
  });

  testWidgets('opens the menu, closes on a tap outside and on Back', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('sections-menu')), findsNothing);

    await tester.tap(find.byKey(const Key('sections-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sections-menu')), findsOneWidget);
    for (final k in ['games', 'dictionary', 'translator', 'chat', 'settings']) {
      expect(find.byKey(Key('sections-$k')), findsOneWidget);
    }

    await tester.tapAt(const Offset(20, 100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sections-menu')), findsNothing);

    await tester.tap(find.byKey(const Key('sections-button')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sections-menu')), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('a row opens its page and the menu is closed after', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('sections-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sections-settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings page'), findsOneWidget);

    Navigator.of(tester.element(find.text('settings page'))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sections-menu')), findsNothing);
  });
}
