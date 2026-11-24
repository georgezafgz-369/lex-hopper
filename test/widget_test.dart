// Basic smoke test — verifies the app launches and shows the home page.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/dictionary_service.dart';
import 'package:lex_hopper/main.dart';

void main() {
  testWidgets('App launches on the home page', (WidgetTester tester) async {
    // The databases are already downloaded (first launch has its own test).
    DictionaryService.databases.markReady();
    await tester.pumpWidget(const LexHopper());
    expect(find.text('Games'), findsOneWidget);
  });
}
