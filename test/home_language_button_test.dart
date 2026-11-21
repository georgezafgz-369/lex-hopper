// The globe button beside Home on the home page opens the same language
// list as Settings > Language, and choosing there works the same way.

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

  testWidgets('the globe opens the language list; Greek can be secondary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.byKey(const Key('language-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('language-el')), findsOneWidget);

    await tester.tap(find.byKey(const Key('language-el')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('set-secondary')));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.secondaryLanguage, 'el');
  });
}
