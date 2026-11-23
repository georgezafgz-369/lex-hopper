// The translate button beside the globe on the home page slides the
// Translator up from the bottom; its X closes it again.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
  });

  testWidgets('the translate button opens the Translator from the bottom', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.byKey(const Key('translate-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('translate-button')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('translator-sheet-close')), findsOneWidget);
    // In the sheet, the X replaces the page's own top bar.
    expect(find.byKey(const Key('translator-back')), findsNothing);

    await tester.tap(find.byKey(const Key('translator-sheet-close')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(const Key('translate-button')), findsOneWidget);
  });
}
