// The Chat with AI page: starters before the first message, then your
// message on the right and the reply on the left (with no AI turned on,
// a note saying where to turn one on).

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
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
    expect(find.textContaining('turn on an AI model'), findsOneWidget);
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
    expect(find.textContaining('turn on an AI model'), findsOneWidget);
  });

  test('the AI practises the secondary language, explaining in the main', () {
    final both = chatInstructions(main: 'el', second: 'es');
    expect(both, contains('main language is Greek'));
    expect(both, contains('practising Spanish'));
    expect(both, contains('Talk with them in Spanish'));
    expect(both, contains('in one short line in Greek'));
    // No secondary language: the main one only.
    final one = chatInstructions(main: 'de');
    expect(one, contains('Always reply in German'));
    expect(one, isNot(contains('practising')));
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

  testWidgets('opened from the teacher cloud: its greeting comes first', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          settings: const RouteSettings(arguments: 'Γεια σου! Ready?'),
          builder: (_) => const ChatPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-welcome')), findsNothing);
    expect(find.text('Γεια σου! Ready?'), findsOneWidget);
  });
}
