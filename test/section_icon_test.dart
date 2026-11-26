// Each section has its doodle icon in its own colour, in light and dark
// mode, and the home page shows the four of them on its cards.

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/app_settings.dart';
import 'package:lex_hopper/design_system.dart';
import 'package:lex_hopper/home_page.dart';
import 'package:lex_hopper/section_icon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

void main() {
  test('each home section has its own colour, light and dark', () {
    const home = [
      Section.games,
      Section.dictionary,
      Section.translator,
      Section.settings,
    ];
    for (final b in Brightness.values) {
      final colours = {for (final s in home) SectionIcon.colorOf(s, b)};
      expect(colours, hasLength(home.length), reason: '$b');
      // Language opens the same list as Settings > Language.
      expect(
        SectionIcon.colorOf(Section.language, b),
        SectionIcon.colorOf(Section.settings, b),
      );
    }
    expect(
      SectionIcon.colorOf(Section.games, Brightness.light),
      AppColors.coralLight,
    );
  });

  test('the drawings use the theme colours, nothing left to fill in', () {
    for (final s in Section.values) {
      for (final b in Brightness.values) {
        final svg = SectionIcon.svgOf(s, b);
        // The compact one is the same picture without the extras.
        final compact = SectionIcon.svgOf(s, b, compact: true);
        expect(compact.length, lessThan(svg.length), reason: '$s');
        expect(compact, isNot(contains('{')));
        expect(svg, isNot(contains('{')), reason: '$s $b');
        expect(svg, contains(hex(SectionIcon.colorOf(s, b))));
        final ink = b.resolve(
          light: AppColors.inkLight,
          dark: AppColors.inkDark,
        );
        expect(svg, contains(hex(ink)));
      }
    }
  });

  testWidgets('the home page shows the four section icons', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.instance.load();
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    for (final s in [
      Section.games,
      Section.dictionary,
      Section.translator,
      Section.settings,
    ]) {
      expect(find.byKey(Key('section-icon-${s.name}')), findsOneWidget);
    }
  });

  test('every language has its landmark, with nothing left to fill in', () {
    for (final l in appLanguages) {
      expect(FlagIcon.has(l.code), isTrue, reason: l.code);
      for (final b in Brightness.values) {
        final svg = FlagIcon.svgOf(l.code, b);
        expect(svg, isNot(contains('{')), reason: '${l.code} $b');
      }
    }
    // Neighbours in the list get different colours.
    for (final b in Brightness.values) {
      expect(FlagIcon.colorOf('en', b), isNot(FlagIcon.colorOf('el', b)));
    }
    expect(FlagIcon.has('xx'), isFalse);
  });
}
