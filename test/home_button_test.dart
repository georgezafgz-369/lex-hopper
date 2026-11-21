// The home button goes back to the home page with a single tap.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('one tap on the home button opens the home page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => const Scaffold(body: Text('Home page')),
          '/other': (_) => const Scaffold(body: HomeButton()),
        },
        initialRoute: '/other',
      ),
    );
    await tester.pumpAndSettle();
    // initialRoute '/other' also puts '/' underneath; start from '/other'.
    expect(find.byKey(const Key('home-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-button')));
    await tester.pumpAndSettle();
    expect(find.text('Home page'), findsOneWidget);
    expect(find.byKey(const Key('home-button')), findsNothing);
  });
}
