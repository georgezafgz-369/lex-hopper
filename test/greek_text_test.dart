// The app's own text appears in Greek when the locale is Greek.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_text.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:lex_hopper/settings_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget greekApp(Widget home) => MaterialApp(
  locale: const Locale('el'),
  supportedLocales: const [Locale('en'), Locale('el')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: home,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('home page in Greek', (tester) async {
    await tester.pumpWidget(greekApp(const HomePage()));
    expect(find.text('Παιχνίδια'), findsOneWidget);
    expect(
      find.text('Σταυρόλεξο · Βρες τις Λέξεις · Αινίγματα'),
      findsOneWidget,
    );
    expect(find.text('Αναζήτηση στο λεξικό...'), findsOneWidget);
  });

  testWidgets('settings in Greek', (tester) async {
    await tester.pumpWidget(greekApp(const SettingsPage()));
    expect(find.text('ΡΥΘΜΙΣΕΙΣ'), findsOneWidget);
    expect(find.text('Σκούρο θέμα'), findsOneWidget);
    expect(find.text('Ελληνικά'), findsOneWidget); // current language
  });

  test('level names and part of speech in Greek', () {
    expect(AppText.greek.level(2), 'Επίπεδο Δύο');
    // The Continue card names the level, not "No.".
    expect(
      AppText.greek.continueSubtitle(5),
      'Συνέχισε από εκεί που σταμάτησες — Επίπεδο 5.',
    );
    expect(
      AppText.english.continueWithSubject(5, 'Language'),
      'Pick up where you left off — Level 5, Language.',
    );
    expect(AppText.greek.level(40), 'Επίπεδο 40');
    expect(AppText.greek.partOfSpeechName('adj'), 'Επίθετο');
    expect(AppText.english.level(2), 'Level Two');
    expect(AppText.upper('Ουσιαστικό'), 'ΟΥΣΙΑΣΤΙΚΟ');
    expect(AppText.upper('Noun'), 'NOUN');
  });
}
