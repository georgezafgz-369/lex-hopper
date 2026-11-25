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
}
