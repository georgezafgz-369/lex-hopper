// The floating bottom menu: a + button that opens a round button per
// section, the current page marked, and out of the way while the keyboard
// is up.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/bottom_menu.dart';
import 'package:lex_hopper/section_icon.dart';
import 'package:material_ui/material_ui.dart';

Widget page() => const MaterialApp(
  home: Scaffold(
    body: BottomMenu(current: Section.games, child: SizedBox.expand()),
  ),
);

void main() {
  setUp(() => BottomMenu.open.value = false);

  testWidgets('starts closed: only the + button; it opens and closes', (
    tester,
  ) async {
    await tester.pumpWidget(page());
    expect(find.byKey(const Key('bottom-menu-toggle')), findsOneWidget);
    expect(find.byKey(const Key('bottom-menu-games')), findsNothing);
    await tester.tap(find.byKey(const Key('bottom-menu-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bottom-menu-games')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bottom-menu-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bottom-menu-games')), findsNothing);
  });

  testWidgets('stays open from page to page', (tester) async {
    BottomMenu.open.value = true;
    await tester.pumpWidget(page());
    expect(find.byKey(const Key('bottom-menu-dictionary')), findsOneWidget);
  });

  testWidgets('a round button for each section', (tester) async {
    BottomMenu.open.value = true;
    await tester.pumpWidget(page());
    expect(find.byKey(const Key('bottom-menu')), findsOneWidget);
    for (final s in const [
      Section.home,
      Section.games,
      Section.dictionary,
      Section.translator,
      Section.settings,
    ]) {
      expect(find.byKey(Key('bottom-menu-${s.name}')), findsOneWidget);
    }
  });

  testWidgets('doodle icons; the current page a little bigger', (tester) async {
    BottomMenu.open.value = true;
    await tester.pumpWidget(page());
    expect(find.byKey(const Key('section-icon-games-compact')), findsOneWidget);
    double scale(String s) => tester
        .widget<AnimatedScale>(find.byKey(Key('bottom-menu-scale-$s')))
        .scale;
    expect(scale('games'), greaterThan(scale('home')));
    expect(scale('home'), scale('settings'));
  });

  testWidgets('hidden while the keyboard is up', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(page());
    expect(find.byKey(const Key('bottom-menu')), findsNothing);
  });
}
