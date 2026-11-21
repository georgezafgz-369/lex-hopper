// With a secondary language, home and Games page texts show their
// translation: titles and section labels right next to them, descriptions on
// a small grey line underneath. Without one, only the main language.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:lex_hopper/games_page.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Widget app() => const MaterialApp(home: HomePage());
  Widget gamesApp() => const MaterialApp(home: GamesPage());

  testWidgets('no secondary language: main language only', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Games'), findsOneWidget);
    expect(find.textContaining('Παιχνίδια', findRichText: true), findsNothing);
  });

  testWidgets('home: secondary language adds a translation to each text', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await AppSettings.instance.setSecondaryLanguage('el');
    await tester.pump();

    // Titles and section labels: the translation on the same line.
    expect(find.text('Games  Παιχνίδια', findRichText: true), findsOneWidget);
    expect(find.text('Dictionary  Λεξικό', findRichText: true), findsOneWidget);
    expect(find.text('REFERENCE  ΑΝΑΦΟΡΑ', findRichText: true), findsOneWidget);

    // Translations are orange; the main text isn't.
    final title = tester.widget<RichText>(
      find.text('Games  Παιχνίδια', findRichText: true),
    );
    final spans = <TextSpan>[];
    title.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    final mainSpan = spans.firstWhere((x) => x.text == 'Games');
    final secondSpan = spans.firstWhere((x) => x.text!.contains('Παιχνίδια'));
    expect(mainSpan.style?.color, isNot(AppColors.translationLight));
    expect(secondSpan.style!.color, AppColors.translationLight);
    // Plain orange: no shadow, no background.
    expect(secondSpan.style!.shadows, isNull);
    expect(secondSpan.style!.backgroundColor, isNull);

    // Descriptions: the translation on a smaller line underneath.
    final main = tester.getTopLeft(
      find.text('Look up words and their definitions.'),
    );
    final second = tester.getTopLeft(
      find.text('Βρες λέξεις και τις σημασίες τους.'),
    );
    expect(second.dy, greaterThan(main.dy));
    final line = tester.widget<Text>(
      find.text('Βρες λέξεις και τις σημασίες τους.'),
    );
    expect(line.style!.color, AppColors.translationLight);

    // The search hint holds both languages.
    final field = tester.widget<TextField>(
      find.byKey(const Key('home-search')),
    );
    expect(field.decoration!.hintText, contains('Αναζήτηση στο λεξικό'));

    // Removing it goes back to one language.
    await AppSettings.instance.setSecondaryLanguage(null);
    await tester.pump();
    expect(find.text('Games'), findsOneWidget);
    expect(find.textContaining('Παιχνίδια', findRichText: true), findsNothing);
  });

  testWidgets('Games page: game titles and descriptions get translations', (
    tester,
  ) async {
    await tester.pumpWidget(gamesApp());
    expect(find.text('Crossword'), findsOneWidget);

    await AppSettings.instance.setSecondaryLanguage('el');
    await tester.pump();
    expect(
      find.text('Crossword  Σταυρόλεξο', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('GAMES  ΠΑΙΧΝΙΔΙΑ', findRichText: true), findsOneWidget);
    final main = tester.getTopLeft(
      find.text('Set across and down in the printed newspaper tradition.'),
    );
    final second = tester.getTopLeft(
      find.text('Οριζόντια και κάθετα, όπως στο σταυρόλεξο της εφημερίδας.'),
    );
    expect(second.dy, greaterThan(main.dy));
    expect(find.text('Έρχεται σύντομα'), findsOneWidget); // Riddles
  });
}
