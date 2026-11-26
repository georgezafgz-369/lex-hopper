// The home page has a Translator card right under Dictionary; tapping it
// opens the Translator page, whose back button returns home.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:lex_hopper/translator_page.dart';
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
      '/translator': (_) => const TranslatorPage(),
    },
  );

  testWidgets('Translator card sits under Dictionary and opens its page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    await tester.pumpWidget(app());

    expect(find.text('Translator'), findsOneWidget);
    expect(find.text('Translate words and phrases.'), findsOneWidget);
    final dictionary = tester.getRect(find.text('Dictionary'));
    final translator = tester.getRect(find.text('Translator'));
    final settings = tester.getRect(find.text('Settings'));
    expect(translator.top, greaterThan(dictionary.bottom));
    expect(translator.bottom, lessThan(settings.top));

    await tester.tap(find.byKey(const Key('translator-card')));
    await tester.pumpAndSettle();
    expect(find.byType(TranslatorPage), findsOneWidget);
    expect(find.byKey(const Key('translator-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('translator-back')));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('under Translator, past a line: Learn, coming soon', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    final learn = find.byKey(const Key('learn-card'));
    expect(learn, findsOneWidget);
    expect(
      tester.getRect(learn).top,
      greaterThan(
        tester.getRect(find.byKey(const Key('translator-card'))).bottom,
      ),
    );
    expect(find.text('Language Lessons'), findsOneWidget);
    expect(
      find.descendant(of: learn, matching: find.text('Coming soon')),
      findsOneWidget,
    );
    // A line between Translator and it.
    final lines = find
        .byType(Divider)
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)).top);
    final translatorBottom = tester
        .getRect(find.byKey(const Key('translator-card')))
        .bottom;
    expect(
      lines.any((y) => y > translatorBottom && y < tester.getRect(learn).top),
      isTrue,
    );
  });
}
