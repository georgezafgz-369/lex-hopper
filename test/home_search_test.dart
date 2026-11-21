// The home page search bar looks words up in the dictionary.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/dictionary_page.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('submitting a word opens the dictionary with it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('Search dictionary...'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('home-search')), 'apple');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final page = tester.widget<DictionaryPage>(find.byType(DictionaryPage));
    expect(page.initialQuery, 'apple');
  });

  testWidgets('pressing the search icon searches too', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.enterText(find.byKey(const Key('home-search')), 'pear');
    await tester.tap(find.byKey(const Key('search-icon')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final page = tester.widget<DictionaryPage>(find.byType(DictionaryPage));
    expect(page.initialQuery, 'pear');
  });

  testWidgets('the search icon does nothing with an empty field', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.tap(find.byKey(const Key('search-icon')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DictionaryPage), findsNothing);
  });

  // Coming back from the dictionary, the search bar is no longer selected,
  // so the keyboard doesn't pop up again.
  for (final (how, viaIcon) in [
    ('keyboard key', false),
    ('search icon', true),
  ]) {
    testWidgets('back from a search ($how): search bar not focused', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      final field = find.byKey(const Key('home-search'));
      await tester.tap(field);
      await tester.enterText(field, 'apple');
      if (viaIcon) {
        await tester.tap(find.byKey(const Key('search-icon')));
      } else {
        await tester.testTextInput.receiveAction(TextInputAction.search);
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DictionaryPage), findsOneWidget);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });
  }
}
