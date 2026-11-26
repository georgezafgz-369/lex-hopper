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
    expect(both, contains('Always reply in Greek'));
    expect(both, contains('in one short line in Greek'));
    // No secondary language: the main one only.
    final one = chatInstructions(main: 'de');
    expect(one, contains('Always reply in German'));
    expect(one, isNot(contains('learning Spanish')));
  });

  testWidgets('the AI\'s answers have a listen button, yours don\'t', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: ChatPage()));
    await tester.enterText(find.byKey(const Key('chat-input')), 'Hola');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
    // Message 0 is yours, 1 the reply.
    expect(find.byKey(const Key('chat-speak-0')), findsNothing);
    expect(find.byKey(const Key('chat-speak-1')), findsOneWidget);
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
    expect(find.textContaining('Hello! I'), findsOneWidget);
    expect(find.byKey(const Key('ai-offer-download')), findsOneWidget);
    final translation = tester.widget<Text>(
      find.byKey(const Key('chat-translation')),
    );
    expect(translation.textSpan!.toPlainText(), contains('Γεια σου!'));
    expect(find.byKey(const Key('chat-translation-speak')), findsOneWidget);
  });
}
