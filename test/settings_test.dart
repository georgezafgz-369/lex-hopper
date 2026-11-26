// Settings page: dark mode switch, language list and the AI translator.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/settings_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Widget app() => const MaterialApp(home: SettingsPage());

  testWidgets('shows the Language, Dark mode and Feedback cards', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.byKey(const Key('settings-language')), findsOneWidget);
    expect(find.byKey(const Key('settings-dark-mode')), findsOneWidget);
    expect(find.byKey(const Key('settings-feedback')), findsOneWidget);
    expect(find.text('About the app'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('the switch turns dark mode on and saves it', (tester) async {
    await tester.pumpWidget(app());
    // Not set yet: follows the phone (light in tests).
    expect(AppSettings.instance.themeMode, ThemeMode.system);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('settings-dark-mode')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pump();
    expect(AppSettings.instance.darkMode, isTrue);
    expect(AppSettings.instance.themeMode, ThemeMode.dark);
    expect(find.text('On'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings_dark_mode'), isTrue);
  });

  testWidgets('Greek can be picked; unfinished languages cannot', (
    tester,
  ) async {
    // Tall enough for the whole list, flags and all.
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsWidgets);
    expect(find.byKey(const Key('flag-de')), findsOneWidget);

    // German isn't ready: tapping it changes nothing.
    await tester.tap(find.text('German'));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.language, isNull);

    // Tapping a language asks: main or secondary.
    await tester.tap(find.text('Greek'));
    await tester.pumpAndSettle();
    expect(find.text('Set as secondary language'), findsOneWidget);
    await tester.tap(find.byKey(const Key('set-main')));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.language, 'el');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_language'), 'el');
  });

  testWidgets('a language can be secondary, swapped with main, or removed', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.byKey(const Key('settings-language')));
    await tester.pumpAndSettle();

    // English is the main language here: Greek becomes secondary.
    await tester.tap(find.byKey(const Key('language-el')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-secondary')));
    await tester.pumpAndSettle();
    final settings = AppSettings.instance;
    expect(settings.secondaryLanguage, 'el');
    // The tag reads "Secondary" with its translation (Greek is now the
    // secondary language, so every label shows it too).
    expect(
      find.text('Secondary  Δευτερεύουσα', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Language  Γλώσσα', findRichText: true), findsWidgets);
    // The list names each language in the main language, with the
    // secondary one's name next to it.
    expect(find.text('Arabic  Αραβικά', findRichText: true), findsOneWidget);
    // The Language card names the languages in each line's own language.
    expect(find.text('English · secondary: Greek'), findsOneWidget);
    expect(find.text('Αγγλικά · δευτερεύουσα: Ελληνικά'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_secondary_language'), 'el');

    // The secondary language is listed right after the main one.
    final english = tester.getTopLeft(find.byKey(const Key('language-en')));
    final greek = tester.getTopLeft(find.byKey(const Key('language-el')));
    final arabic = tester.getTopLeft(find.byKey(const Key('language-ar')));
    expect(english.dy < greek.dy && greek.dy < arabic.dy, isTrue);

    // Making the secondary the main one swaps them.
    await settings.setLanguage('el');
    expect(settings.language, 'el');
    expect(settings.secondaryLanguage, 'en');

    // The main language can't also be secondary; and it can be removed.
    await settings.setSecondaryLanguage('el');
    expect(settings.secondaryLanguage, 'en');
    await settings.setSecondaryLanguage(null);
    expect(settings.secondaryLanguage, isNull);
    expect(prefs.getString('settings_secondary_language'), isNull);
  });

  testWidgets('font size buttons change and save the size', (tester) async {
    // Tall enough to show the Font size card, under the AI model's.
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    expect(AppSettings.instance.fontSize, FontSizeOption.medium);
    await tester.tap(find.byKey(const Key('font-size-large')));
    await tester.pump();
    expect(AppSettings.instance.fontSize, FontSizeOption.large);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_font_size'), 'large');
  });

  testWidgets('the AI translator asks before its 1 GB download', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('settings-ai-translator'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Off')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('ai-translator-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-download-dialog')), findsOneWidget);
    expect(find.textContaining('1045 MB'), findsOneWidget);

    // Cancel: nothing downloads and it stays off.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-download-dialog')), findsNothing);
    expect(AppSettings.instance.aiTranslator, isFalse);
    expect(find.byKey(const Key('ai-download-progress')), findsNothing);
  });

  testWidgets('About credits the offline translator (CC BY 4.0)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    // Scrolled into view (and out from under the bottom menu) first.
    await tester.ensureVisible(find.byKey(const Key('settings-about')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-about')));
    await tester.pumpAndSettle();
    expect(find.textContaining('OPUS-MT by Helsinki-NLP'), findsOneWidget);
    expect(find.textContaining('CC BY 4.0'), findsOneWidget);
  });

  testWidgets('each Settings card has its doodle icon', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final name in const [
      'language',
      'darkMode',
      'fontSize',
      'aiTranslator',
      'feedback',
      'about',
    ]) {
      expect(find.byKey(Key('section-icon-$name')), findsOneWidget);
    }
  });

  testWidgets('four AI models to pick from, two to a row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    for (final id in ['eurollm', 'gemma4', 'qwen35', 'qwen35mini']) {
      expect(find.byKey(Key('ai-model-$id')), findsOneWidget, reason: id);
    }
    expect(find.text('Qwen 3.5'), findsOneWidget);
    expect(find.text('Qwen Mini'), findsOneWidget);
    expect(find.text('0.5 GB'), findsOneWidget);
    final euro = tester.getRect(find.byKey(const Key('ai-model-eurollm')));
    final gemma = tester.getRect(find.byKey(const Key('ai-model-gemma4')));
    final qwen = tester.getRect(find.byKey(const Key('ai-model-qwen35')));
    expect(gemma.top, closeTo(euro.top, 2)); // same row
    expect(qwen.top, greaterThan(euro.bottom)); // next row
  });
}
