// Basic smoke test — verifies the app launches and shows the home page.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/main.dart';

void main() {
  testWidgets('App launches on the home page', (WidgetTester tester) async {
    await tester.pumpWidget(const LexHopper());
    expect(find.text('Games'), findsOneWidget);
  });
}
