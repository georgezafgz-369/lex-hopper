// The Chat with AI page: starters before the first message, then your
// message on the right and the reply on the left (with no AI turned on,
// a note saying where to turn one on).

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/app_text.dart';
import 'package:lex_hopper/chat_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    ChatSession.instance.reset();
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  testWidgets('a starter sends a message and gets a reply', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));
    expect(find.byKey(const Key('chat-welcome')), findsOneWidget);

    await tester.tap(find.byKey(const Key('chat-starter-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-welcome')), findsNothing);
    expect(find.text('Let’s order a coffee in a café'), findsOneWidget);
    expect(find.textContaining('download the AI'), findsOneWidget);
  });

  testWidgets('typing and sending adds your message', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));
    await tester.enterText(find.byKey(const Key('chat-input')), 'Hola');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.text('Hola'), findsOneWidget);
    // An empty message isn't sent.
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('download the AI'), findsOneWidget);
  });

  test('the AI talks in the main language; the app adds the translation', () {
    final both = chatInstructions(main: 'el', second: 'es');
    expect(both, contains('main language is Greek'));
    expect(both, contains('learning Spanish'));
    expect(both, contains('Reply in Greek only'));
    expect(both, contains('do not translate your reply'));
    expect(both, contains('never invent a mistake'));
    expect(both, contains('in one short line in Greek'));
    // No secondary language: the main one only.
    final one = chatInstructions(main: 'de');
    expect(one, contains('Always reply in German'));
    expect(one, isNot(contains('learning Spanish')));
  });

  testWidgets('a speaker after each sentence of the AI\'s answers, not yours', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));
    await tester.enterText(find.byKey(const Key('chat-input')), 'Hola');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    // Yours has no speakers; the reply has one after each sentence.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Hola'),
          matching: find.byType(ChatBubble),
        ),
        matching: find.byIcon(Icons.volume_up_outlined),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('chat-sentence-speak-0')), findsWidgets);
  });

  test('only the practised language is read aloud', () {
    const mixed =
        'Καλημέρα! Τι θέλεις; (Kaliméra! Ti théleis?)\n\nWhat would you like?';
    expect(
      speakablePart(mixed, language: 'el', main: 'en'),
      'Καλημέρα! Τι θέλεις;',
    );
    expect(
      speakablePart('Hola, ¿qué tal?', language: 'es', main: 'en'),
      'Hola, ¿qué tal?',
    );
  });

  testWidgets('no AI yet: the teacher offers to download it, with its '
      'translation and a speaker', (tester) async {
    await AppSettings.instance.setSecondaryLanguage('el');
    addTearDown(() => AppSettings.instance.setSecondaryLanguage(null));
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));
    await ChatSession.instance.greet(AppText.forCode('en'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('your language teacher', findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-offer-download')), findsOneWidget);
    final translation = tester.widget<Text>(
      find.byKey(const Key('chat-translation')),
    );
    expect(translation.textSpan!.toPlainText(), contains('Γεια σου!'));
    expect(find.byKey(const Key('chat-translation-speak-0')), findsOneWidget);
  });

  test('notes after a --- line and ** marks are cut from replies', () {
    expect(
      cleanReply(
        'Hello! I am **fine**.\n\n---\n\n**Teacher\'s Note:** correct.',
      ),
      'Hello! I am fine.',
    );
    expect(cleanReply('  Just this.  '), 'Just this.');
    // A reply that starts with a line isn't cut to nothing.
    expect(cleanReply('---\nHi'), '---\nHi');
  });

  test('replies are cut into sentences, nothing lost', () {
    const text = 'Hello! How are you? Πώς είσαι; Fine.\nNew line';
    final parts = sentencesOf(text);
    expect(parts.join(), text);
    expect(parts.map((p) => p.trim()), [
      'Hello!',
      'How are you?',
      'Πώς είσαι;',
      'Fine.',
      'New line',
    ]);
    // A decimal point or an abbreviation without a space isn't an end.
    expect(sentencesOf('It costs 2.50 euros.'), ['It costs 2.50 euros.']);
  });

  test('each sentence is read in the voice of its letters', () {
    expect(voiceFor('Hello there.', main: 'en', second: 'el'), 'en');
    expect(voiceFor('Καλημέρα!', main: 'en', second: 'el'), 'el');
    expect(voiceFor('Привет!', main: 'en'), 'ru');
    // App in Greek, Latin sentence: the secondary language if Latin.
    expect(voiceFor('Bonjour !', main: 'el', second: 'fr'), 'fr');
    expect(voiceFor('Hello.', main: 'ru', second: 'el'), 'en');
  });
}
