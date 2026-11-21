// The word of the day card at the top of the home page: shows the word,
// its part of speech and meaning, its translation with a secondary
// language, and nothing at all when there is no word.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/dictionary_service.dart';
import 'package:lex_hopper/word_of_the_day_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

DictionaryEntry crust() => DictionaryEntry.fromMap({
  'id': 1,
  'word': 'crust',
  'pos': 'noun',
  'meaning': 'the outer layer of the Earth',
  'domain': 'general',
  'source': 'wordnet',
  'sense': 1,
});

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Widget app(WordOfTheDayLoader load) => MaterialApp(
    home: Scaffold(
      body: WordOfTheDayCard(load: load, today: DateTime(2026, 11, 20)),
    ),
  );

  testWidgets('shows the word, part of speech, meaning and date', (
    tester,
  ) async {
    String? asked;
    await tester.pumpWidget(
      app((lang) async {
        asked = lang;
        return WordOfTheDay(crust(), 'φλοιός');
      }),
    );
    await tester.pump();

    expect(asked, 'en');
    expect(find.text('WORD OF THE DAY'), findsOneWidget);
    expect(find.text('Fri 20 Nov'), findsOneWidget);
    expect(find.text('Crust', findRichText: true), findsOneWidget);
    expect(find.text('Noun'), findsOneWidget);
    expect(find.text('The outer layer of the Earth.'), findsOneWidget);
    expect(find.byKey(const Key('word-of-the-day-speak')), findsOneWidget);
    // No secondary language: no translation.
    expect(find.textContaining('φλοιός', findRichText: true), findsNothing);
  });

  testWidgets('with a secondary language, the translation follows the word', (
    tester,
  ) async {
    await AppSettings.instance.setSecondaryLanguage('el');
    await tester.pumpWidget(app((_) async => WordOfTheDay(crust(), 'φλοιός')));
    await tester.pump();
    expect(find.text('Crust  φλοιός', findRichText: true), findsOneWidget);
    await AppSettings.instance.setSecondaryLanguage(null);
  });

  testWidgets('no word (or an error): the card is hidden', (tester) async {
    await tester.pumpWidget(app((_) async => null));
    await tester.pump();
    expect(find.byKey(const Key('word-of-the-day')), findsNothing);

    await tester.pumpWidget(app((_) async => throw Exception('no db')));
    await tester.pump();
    expect(find.byKey(const Key('word-of-the-day')), findsNothing);
  });
}
