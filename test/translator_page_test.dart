// The Translator page: type in one panel and the translation appears in the
// other as you type (or at once on Enter); swap the languages; first-time preparation and failures are
// shown in the translation panel. A fake translator stands in for the
// phone's.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:lex_hopper/dictionary_service.dart';
import 'package:lex_hopper/saved_translations.dart';
import 'package:lex_hopper/translator_page.dart';
import 'package:lex_hopper/translator_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTranslator implements Translator {
  bool ready;
  bool fail;

  /// Throws [NoTranslatorYet], as when nothing is downloaded.
  bool none = false;
  Completer<void>? preparing;
  final calls = <String>[];

  FakeTranslator({this.ready = true, this.fail = false});

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<void> prepare() async {
    preparing = Completer<void>();
    await preparing!.future;
    ready = true;
  }

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    calls.add('$from>$to:$text');
    if (none) throw const NoTranslatorYet();
    if (fail) throw Exception('no model');
    return '[$to] $text';
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Translator translator, {
    Map<String, List<WordTranslation>> dictionary = const {},
    Map<String, String> lexicon = const {},
    SavedTranslations? saved,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: TranslatorPage(
          translator: translator,
          saved: saved ?? MemorySavedTranslations(),
          lookup: (text, language) async {
            final key = '$language:${text.toLowerCase()}';
            return (main: lexicon[key], meanings: dictionary[key] ?? const []);
          },
        ),
      ),
    );
    await tester.pump();
  }

  Finder input() => find.byKey(const Key('translator-input'));
  String output(WidgetTester tester) => tester
      .widget<SelectableText>(find.byKey(const Key('translator-output')))
      .data!;

  /// Let the live translation run (typing paused long enough).
  Future<void> afterPause(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('empty: big hint, Paste, and the language bar', (tester) async {
    await pumpPage(tester, FakeTranslator());
    expect(find.text('Translate text'), findsOneWidget);
    expect(find.byKey(const Key('paste-button')), findsOneWidget);
    expect(find.byKey(const Key('translator-output')), findsNothing);
    expect(find.byKey(const Key('clear-input')), findsNothing);
    // Language bar at the bottom: English ⇄ Greek.
    final from = tester.getCenter(find.byKey(const Key('from-language')));
    final swap = tester.getCenter(find.byKey(const Key('swap-button')));
    final to = tester.getCenter(find.byKey(const Key('to-language')));
    expect(from.dx, lessThan(swap.dx));
    expect(swap.dx, lessThan(to.dx));
    expect(from.dy, greaterThan(600)); // near the bottom
    expect(
      find.descendant(
        of: find.byKey(const Key('from-language')),
        matching: find.text('English'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('with text: ✕, 🔊 / copy, a divider, the translation', (
    tester,
  ) async {
    await pumpPage(tester, FakeTranslator());
    await tester.enterText(input(), 'cat');
    await afterPause(tester);
    expect(find.byKey(const Key('paste-button')), findsNothing);
    expect(find.byKey(const Key('clear-input')), findsOneWidget);
    expect(find.byKey(const Key('speak-input')), findsOneWidget);
    expect(find.byKey(const Key('speak-output')), findsOneWidget);
    expect(find.byKey(const Key('copy-output')), findsOneWidget);
    // The translation sits under the text, with the target language name.
    final label = tester.getTopLeft(find.byKey(const Key('target-label')));
    expect(label.dy, greaterThan(tester.getBottomLeft(input()).dy));
    expect(find.text('Greek'), findsWidgets);
    // The translation is in ink (black), not orange.
    final shown = tester.widget<SelectableText>(
      find.byKey(const Key('translator-output')),
    );
    expect(shown.style!.color, AppColors.inkLight);

    // ✕ empties both.
    await tester.tap(find.byKey(const Key('clear-input')));
    await afterPause(tester);
    expect(find.text('Translate text'), findsOneWidget);
    expect(find.byKey(const Key('translator-output')), findsNothing);
  });

  testWidgets('Paste puts the clipboard text in and translates it', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': ' hello '} : null,
    );
    final fake = FakeTranslator();
    await pumpPage(tester, fake);
    await tester.tap(find.byKey(const Key('paste-button')));
    await afterPause(tester);
    expect(tester.widget<TextField>(input()).controller!.text, 'hello');
    expect(output(tester), '[el] hello');
    expect(fake.calls, ['en>el:hello']); // once, not again after the pause
  });

  testWidgets('there is no Translate button', (tester) async {
    await pumpPage(tester, FakeTranslator());
    expect(find.byKey(const Key('translate-button')), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets('typing translates live once typing pauses', (tester) async {
    final fake = FakeTranslator();
    await pumpPage(tester, fake);
    await tester.enterText(input(), 'good');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(input(), 'good morning');
    await tester.pump(const Duration(milliseconds: 200));
    expect(fake.calls, isEmpty); // still typing

    await afterPause(tester);
    // Only the finished text was translated, not every step.
    expect(fake.calls, ['en>el:good morning']);
    expect(output(tester), '[el] good morning');
  });

  testWidgets('Enter translates at once and closes the keyboard', (
    tester,
  ) async {
    final fake = FakeTranslator();
    await pumpPage(tester, fake);
    await tester.tap(input());
    await tester.enterText(input(), 'thank you');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(fake.calls, ['en>el:thank you']); // no pause needed
    expect(output(tester), '[el] thank you');
    final field = tester.widget<TextField>(input());
    expect(field.focusNode!.hasFocus, isFalse);

    await afterPause(tester);
    expect(fake.calls, hasLength(1)); // not translated twice
  });

  testWidgets('a typed Enter (hardware keyboard) translates, no new line', (
    tester,
  ) async {
    final fake = FakeTranslator();
    await pumpPage(tester, fake);
    await tester.enterText(input(), 'good day\n');
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextField>(input()).controller!.text, 'good day');
    expect(fake.calls, ['en>el:good day']);
    await afterPause(tester);
    expect(fake.calls, hasLength(1));
  });

  testWidgets('clearing the text clears the translation', (tester) async {
    final fake = FakeTranslator();
    await pumpPage(tester, fake);
    await tester.enterText(input(), 'cat');
    await afterPause(tester);
    expect(output(tester), '[el] cat');

    await tester.enterText(input(), '');
    await afterPause(tester);
    expect(find.byKey(const Key('translator-output')), findsNothing);
    expect(fake.calls, hasLength(1));
  });

  testWidgets('Swap flips the languages and translates back', (tester) async {
    final fake = FakeTranslator();
    await pumpPage(tester, fake);
    await tester.enterText(input(), 'hello');
    await afterPause(tester);

    await tester.tap(find.byKey(const Key('swap-button')));
    await tester.pumpAndSettle();
    // Greek first now; the translation became the text to translate.
    expect(
      tester.widget<Text>(find.byKey(const Key('source-label'))).data,
      'Greek',
    );
    expect(fake.calls.last, 'el>en:[el] hello');
    expect(output(tester), '[en] [el] hello');
  });

  for (final pill in ['from-language', 'to-language']) {
    testWidgets('tapping a language ($pill) in the bar swaps too', (
      tester,
    ) async {
      await pumpPage(tester, FakeTranslator());
      await tester.tap(find.byKey(Key(pill)));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('source-label'))).data,
        'Greek',
      );
    });
  }

  testWidgets('top bar: back, dictionary search, globe, home', (tester) async {
    await pumpPage(tester, FakeTranslator());
    final back = tester.getCenter(find.byKey(const Key('translator-back')));
    final search = tester.getCenter(find.byKey(const Key('translator-search')));
    final globe = tester.getCenter(find.byKey(const Key('language-button')));
    final home = tester.getCenter(find.byKey(const Key('home-button')));
    expect(back.dx, lessThan(search.dx));
    expect(search.dx, lessThan(globe.dx));
    expect(globe.dx, lessThan(home.dx));
    expect((search.dy - globe.dy).abs(), lessThan(4)); // one row

    // The globe opens the app's language list.
    await tester.tap(find.byKey(const Key('language-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('language-el')), findsOneWidget);
  });

  testWidgets('first time: says it is getting ready, then translates', (
    tester,
  ) async {
    final fake = FakeTranslator(ready: false);
    await pumpPage(tester, fake);
    expect(output(tester), contains('Getting the translator ready'));

    await tester.enterText(input(), 'cat');
    await tester.pump(const Duration(milliseconds: 400));
    expect(fake.calls, isEmpty); // waits for the models

    fake.preparing!.complete();
    await tester.pumpAndSettle();
    expect(output(tester), '[el] cat');
  });

  testWidgets('a failure says so', (tester) async {
    await pumpPage(tester, FakeTranslator(fail: true));
    await tester.enterText(input(), 'cat');
    await afterPause(tester);
    expect(output(tester), contains("Couldn't translate"));
  });

  testWidgets('no translator yet: says where to get one', (tester) async {
    await pumpPage(tester, FakeTranslator()..none = true);
    await tester.enterText(input(), 'where is the cat');
    await afterPause(tester);
    expect(output(tester), contains('offline translator in Settings'));
    expect(output(tester), isNot(contains("Couldn't translate")));
  });

  testWidgets('Copy puts the translation on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await pumpPage(tester, FakeTranslator());
    await tester.enterText(input(), 'dog');
    await afterPause(tester);
    await tester.tap(find.byKey(const Key('copy-output')));
    await tester.pump();
    expect(copied, '[el] dog');
    expect(find.text('Copied'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  });

  // ── Single words: the translator's word, the dictionary's meanings ─────

  /// A translator that answers from a fixed list.
  FakeTranslator saying(Map<String, String> answers) =>
      _ListTranslator(answers);

  testWidgets('a word: the translator\'s word; the box lists the meanings', (
    tester,
  ) async {
    await pumpPage(
      tester,
      saying({'house': 'σπίτι'}),
      dictionary: {
        'en:house': const [
          WordTranslation('noun', ['κατοικία']),
          WordTranslation('verb', ['στεγάζω']),
        ],
      },
    );
    await tester.enterText(input(), 'house');
    await afterPause(tester);
    expect(output(tester), 'σπίτι'); // the translator wins
    expect(find.byKey(const Key('meanings-box')), findsOneWidget);
    expect(find.text('κατοικία'), findsOneWidget);
    expect(find.text('Verb'), findsOneWidget);
  });

  testWidgets('not in the dictionary: the translator alone, no box', (
    tester,
  ) async {
    await pumpPage(tester, saying({'qwerty': 'κουέρτι'}));
    await tester.enterText(input(), 'qwerty');
    await afterPause(tester);
    expect(output(tester), 'κουέρτι');
    expect(find.byKey(const Key('meanings-box')), findsNothing);
  });

  testWidgets('a word or phrase the lexicon knows: its answer, no machine', (
    tester,
  ) async {
    final fake = FakeTranslator(ready: false); // not even downloaded
    await pumpPage(
      tester,
      fake,
      lexicon: {
        'en:give up': 'εγκαταλείπω',
        'en:bury the hatchet': 'κάνω ειρήνη',
      },
      dictionary: {
        'en:give up': const [
          WordTranslation('verb', ['εγκαταλείπω', 'παραδίδομαι']),
        ],
      },
    );
    await tester.enterText(input(), 'give up');
    await afterPause(tester);
    expect(output(tester), 'εγκαταλείπω');
    expect(find.text('εγκαταλείπω, παραδίδομαι'), findsOneWidget);

    // A long phrase (it lives in the texts database) works the same way.
    await tester.enterText(input(), 'Bury the hatchet');
    await afterPause(tester);
    expect(output(tester), 'κάνω ειρήνη');
    expect(fake.calls, isEmpty); // the machine was never asked
  });

  testWidgets('not in the lexicon: the machine translates it', (tester) async {
    final fake = FakeTranslator();
    await pumpPage(tester, fake, lexicon: {'en:cat': 'γάτα'});
    await tester.enterText(input(), 'where is the beach please');
    await afterPause(tester);
    expect(fake.calls, ['en>el:where is the beach please']);
  });

  // ── Saved translations (this phone's memory) ──────────────────────────────

  testWidgets('a finished text is saved; next time it needs no machine', (
    tester,
  ) async {
    final saved = MemorySavedTranslations();
    final fake = FakeTranslator();
    await pumpPage(tester, fake, saved: saved);

    // Live typing: the steps on the way are not saved.
    await tester.enterText(input(), 'Where is the');
    await afterPause(tester);
    expect(await saved.count(), 0);

    // Enter: done, saved.
    await tester.enterText(input(), 'Where is the beach?');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(await saved.count(), 1);
    expect(
      await saved.find('where is the beach?', from: 'en', to: 'el'),
      '[el] Where is the beach?',
    );

    // Typed again (other spacing and capitals): answered from the memory.
    final calls = fake.calls.length;
    await tester.enterText(input(), '');
    await afterPause(tester);
    await tester.enterText(input(), '  where IS the   beach? ');
    await afterPause(tester);
    expect(output(tester), '[el] Where is the beach?');
    expect(fake.calls.length, calls); // the machine wasn't asked
  });

  for (final (how, key) in [
    ('copy', 'copy-output'),
    ('listen', 'speak-output'),
    ('clear', 'clear-input'),
  ]) {
    testWidgets('$how marks the text as done: saved', (tester) async {
      final saved = MemorySavedTranslations();
      await pumpPage(tester, FakeTranslator(), saved: saved);
      await tester.enterText(input(), 'good night');
      await afterPause(tester);
      expect(await saved.count(), 0);
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(await saved.count(), 1);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  }

  testWidgets('leaving the page saves the last text', (tester) async {
    final saved = MemorySavedTranslations();
    await pumpPage(tester, FakeTranslator(), saved: saved);
    await tester.enterText(input(), 'see you tomorrow');
    await afterPause(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(await saved.count(), 1);
  });

  testWidgets('lexicon answers are not saved (they are in the lexicon)', (
    tester,
  ) async {
    final saved = MemorySavedTranslations();
    await pumpPage(
      tester,
      FakeTranslator(),
      saved: saved,
      lexicon: {'en:give up': 'εγκαταλείπω'},
    );
    await tester.enterText(input(), 'give up');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(await saved.count(), 0);
  });

  test('savedKey treats spacing and capitals as the same text', () {
    expect(savedKey('  Good   Morning '), 'good morning');
  });
}

/// Answers from a fixed list; anything else gets "[to] text".
class _ListTranslator extends FakeTranslator {
  final Map<String, String> answers;
  _ListTranslator(this.answers);

  @override
  Future<String> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    calls.add('$from>$to:$text');
    return answers[text] ?? '[$to] $text';
  }
}
