// The dictionary page is one scroll: filters scroll away, the search bar stays.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/dictionary_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('search bar is pinned; the rest scrolls together', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    // No overscroll stretch, like the real app (main.dart).
    await tester.pumpWidget(
      MaterialApp(
        home: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(overscroll: false),
          child: const DictionaryPage(),
        ),
      ),
    );
    // One scroll view for the whole page.
    expect(find.byType(CustomScrollView), findsOneWidget);

    // The doodle beside Back opens the search field.
    await tester.tap(find.byKey(const Key('dictionary-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final searchBefore = tester.getTopLeft(find.byType(TextField)).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    final searchAfter = tester.getTopLeft(find.byType(TextField)).dy;
    expect(searchAfter, searchBefore); // still at the top
  });
}
