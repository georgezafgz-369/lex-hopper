// ─────────────────────────────────────────────────────────────────────────────
// SECTION ICONS — a doodle for each part of the app (Games, Dictionary,
// Translator, Settings, Home and Language for the menu, and Settings' cards): thick ink lines
// over a flat coloured circle, with sparkles, arrows and squiggles around,
// spilling over the circle's edge.
//
// Drawn as SVG on a 120×120 canvas. {blob}, {ink} and {tile} are filled in
// from the theme: the section's colour, the line colour and the colour of
// the shapes' insides (tiles, pages, bubbles), so the same drawing works in
// light and dark mode. [SectionIcon.compact] leaves out the sparkles and
// squiggles, for small sizes (the side menu).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import 'design_system.dart';

enum Section {
  games,
  dictionary,
  translator,
  settings,
  home,
  language,
  // Settings' own cards.
  darkMode,
  fontSize,
  aiTranslator,
  feedback,
  about,
  // Chat with AI (home page).
  chatAi,
  // Learn a language & linguistics (home page, coming soon).
  learn,
  // The games, on the Games page.
  crossword,
  findWords,
  riddles,
}

class SectionIcon extends StatelessWidget {
  final Section section;
  final double size;

  /// Without the sparkles and squiggles: just the circle and the picture,
  /// for small sizes.
  final bool compact;

  const SectionIcon(
    this.section, {
    super.key,
    this.size = 64,
    this.compact = false,
  });

  /// The section's colour (light / dark). Language shares Settings' colour:
  /// it opens the same list as Settings > Language.
  static Color colorOf(Section s, Brightness b) => switch (s) {
    Section.games => b.resolve(
      light: AppColors.coralLight,
      dark: AppColors.coralDark,
    ),
    Section.dictionary => b.resolve(
      light: AppColors.cornflowerLight,
      dark: AppColors.cornflowerDark,
    ),
    Section.translator => b.resolve(
      light: AppColors.marigoldLight,
      dark: AppColors.marigoldDark,
    ),
    Section.settings || Section.language || Section.about => b.resolve(
      light: AppColors.roseLight,
      dark: AppColors.roseDark,
    ),
    Section.darkMode => b.resolve(
      light: AppColors.cornflowerLight,
      dark: AppColors.cornflowerDark,
    ),
    Section.fontSize => b.resolve(
      light: AppColors.marigoldLight,
      dark: AppColors.marigoldDark,
    ),
    Section.feedback => b.resolve(
      light: AppColors.coralLight,
      dark: AppColors.coralDark,
    ),
    Section.chatAi => b.resolve(
      light: AppColors.cornflowerLight,
      dark: AppColors.cornflowerDark,
    ),
    Section.crossword => b.resolve(
      light: AppColors.marigoldLight,
      dark: AppColors.marigoldDark,
    ),
    Section.findWords => b.resolve(
      light: AppColors.fernLight,
      dark: AppColors.fernDark,
    ),
    Section.riddles => b.resolve(
      light: AppColors.roseLight,
      dark: AppColors.roseDark,
    ),
    Section.learn => b.resolve(
      light: AppColors.claretLight,
      dark: AppColors.claretDark,
    ),
    Section.aiTranslator || Section.home => b.resolve(
      light: AppColors.fernLight,
      dark: AppColors.fernDark,
    ),
  };

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// The drawing with this theme's colours.
  @visibleForTesting
  static String svgOf(Section s, Brightness b, {bool compact = false}) {
    final (main, extras) = _drawings[s]!;
    return (_open + main + (compact ? '' : extras) + _close)
        .replaceAll('{blob}', _hex(colorOf(s, b)))
        .replaceAll(
          '{ink}',
          _hex(b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark)),
        )
        .replaceAll(
          '{tile}',
          _hex(
            b.resolve(
              light: AppColors.gridCellLight,
              dark: AppColors.gridCellDark,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    svgOf(section, Theme.of(context).brightness, compact: compact),
    key: Key('section-icon-${section.name}${compact ? '-compact' : ''}'),
    width: size,
    height: size,
  );
}

const _open =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">'
    '<g fill="none" stroke="{ink}" stroke-width="5" stroke-linecap="round" '
    'stroke-linejoin="round">';
const _close = '</g></svg>';
const _blob = '<circle cx="60" cy="64" r="40" fill="{blob}" stroke="none"/>';

/// An eight-ray sparkle centred on (x, y).
String _sparkle(double x, double y, [double r = 8]) {
  final d = r * 0.7;
  return '<path d="M$x ${y - r} V${y + r} M${x - r} $y H${x + r} '
      'M${x - d} ${y - d} L${x + d} ${y + d} '
      'M${x + d} ${y - d} L${x - d} ${y + d}" stroke-width="4"/>';
}

/// Each section: its main picture (circle included) and the extras around
/// it (sparkles, arrows, squiggles).
final _drawings = <Section, (String, String)>{
  // Games: crossword tiles with letters, a curly arrow and sparkles.
  Section.games: (
    '$_blob'
        '<g transform="rotate(-8 60 60)">'
        '<rect x="32" y="32" width="27" height="27" rx="3" fill="{tile}"/>'
        '<rect x="59" y="32" width="27" height="27" rx="3" fill="{tile}"/>'
        '<rect x="59" y="59" width="27" height="27" rx="3" fill="{tile}"/>'
        '<path d="M38.5 53 L45.5 38 L52.5 53 M41.5 47.5 H49.5"/>'
        '<path d="M67 65 V80 M67 65 H73 A3.7 3.7 0 0 1 73 72.4 H67 '
        'M73 72.4 A3.8 3.8 0 0 1 73 80 H67"/>'
        '</g>',
    '<path d="M20 74 C14 94 32 106 48 100"/>'
        '<path d="M48 100 L39 98 M48 100 L44 92"/>'
        '<path d="M88 22 C93 15 98 29 104 22 C107 18 110 20 112 23"/>'
        '${_sparkle(22, 28)}'
        '<circle cx="100" cy="98" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Dictionary: an open book with "Aa" and lines of text.
  Section.dictionary: (
    '$_blob'
        '<path d="M60 44 C50 37 35 37 24 42 V86 C35 81 50 81 60 88 Z" '
        'fill="{tile}"/>'
        '<path d="M60 44 C70 37 85 37 96 42 V86 C85 81 70 81 60 88 Z" '
        'fill="{tile}"/>'
        '<path d="M60 44 V88"/>'
        '<path d="M31 71 L37.5 54 L44 71 M34 65 H41"/>'
        '<circle cx="50.5" cy="66.5" r="4" stroke-width="4"/>'
        '<path d="M54.5 62 V71" stroke-width="4"/>'
        '<path d="M68 55 H88 M68 63 H88 M68 71 H82" stroke-width="4"/>',
    '${_sparkle(100, 24)}'
        '<path d="M14 98 C20 92 26 104 32 98 C38 92 44 104 50 98"/>'
        '<circle cx="18" cy="30" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Translator: two speech bubbles, "A" and "Ω", with arrows between.
  Section.translator: (
    '$_blob'
        '<path d="M30 28 H62 A10 10 0 0 1 72 38 V54 A10 10 0 0 1 62 64 H42 '
        'L32 74 L34 64 H30 A10 10 0 0 1 20 54 V38 A10 10 0 0 1 30 28 Z" '
        'fill="{tile}"/>'
        '<path d="M38.5 56 L46 36 L53.5 56 M41.5 49 H50.5"/>'
        '<path d="M58 58 H90 A10 10 0 0 1 100 68 V84 A10 10 0 0 1 90 94 '
        'H86 L88 104 L78 94 H58 A10 10 0 0 1 48 84 V68 A10 10 0 0 1 58 58 Z" '
        'fill="{tile}"/>'
        '<path d="M63 86 H69 C61 82 61 66 74 66 C87 66 87 82 79 86 H85"/>',
    '<path d="M80 26 C92 22 102 30 102 44"/>'
        '<path d="M102 44 L97 37 M102 44 L107 38"/>'
        '<path d="M40 102 C28 106 18 98 18 86"/>'
        '<path d="M18 86 L13 93 M18 86 L24 91"/>'
        '${_sparkle(104, 14, 6)}',
  ),

  // Settings: a gear with sparkles and squiggles.
  Section.settings: (
    '$_blob'
        '<path d="M81.5 51.8 L89.4 54.3 L89.4 65.7 L81.5 68.2 L81.0 69.4 '
        'L84.9 76.8 L76.8 84.9 L69.4 81.0 L68.2 81.5 L65.7 89.4 L54.3 89.4 '
        'L51.8 81.5 L50.6 81.0 L43.2 84.9 L35.1 76.8 L39.0 69.4 L38.5 68.2 '
        'L30.6 65.7 L30.6 54.3 L38.5 51.8 L39.0 50.6 L35.1 43.2 L43.2 35.1 '
        'L50.6 39.0 L51.8 38.5 L54.3 30.6 L65.7 30.6 L68.2 38.5 L69.4 39.0 '
        'L76.8 35.1 L84.9 43.2 L81.0 50.6 Z" fill="{tile}"/>'
        '<circle cx="60" cy="60" r="9"/>',
    '${_sparkle(100, 26)}'
        '${_sparkle(20, 92, 6)}'
        '<path d="M8 34 C12 26 22 30 18 37 C14 44 24 48 26 42"/>'
        '<path d="M86 102 C92 96 98 108 104 102"/>',
  ),

  // Learn: a graduation cap with its tassel.
  Section.learn: (
    '$_blob'
        '<path d="M40 62 V78 C48 86 72 86 80 78 V62" fill="{tile}"/>'
        '<path d="M22 54 L60 38 L98 54 L60 70 Z" fill="{tile}"/>'
        '<path d="M92 57 V76" stroke-width="4"/>'
        '<circle cx="92" cy="80" r="4" fill="{ink}" stroke="none"/>',
    '${_sparkle(100, 24)}'
        '<path d="M12 94 C18 88 24 100 30 94"/>'
        '<circle cx="22" cy="30" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Home: a little house with a door and a window.
  Section.home: (
    '$_blob'
        '<path d="M36 56 V90 H84 V56" fill="{tile}"/>'
        '<path d="M28 60 L60 32 L92 60"/>'
        '<path d="M54 90 V72 H66 V90" fill="{blob}"/>'
        '<rect x="70" y="62" width="9" height="9" rx="1.5" stroke-width="4"/>',
    '${_sparkle(100, 24)}'
        '<path d="M12 96 C18 90 24 102 30 96"/>'
        '<circle cx="20" cy="34" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Language: a globe.
  Section.language: (
    '$_blob'
        '<circle cx="60" cy="60" r="28" fill="{tile}"/>'
        '<ellipse cx="60" cy="60" rx="12" ry="28"/>'
        '<path d="M32 60 H88" stroke-width="4"/>'
        '<path d="M36 46 C50 50 70 50 84 46 M36 74 C50 70 70 70 84 74" '
        'stroke-width="4"/>',
    '${_sparkle(100, 22)}'
        '<path d="M14 92 C20 86 26 98 32 92 C38 86 44 98 50 92"/>'
        '<circle cx="98" cy="98" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Dark mode: a crescent moon with little stars.
  Section.darkMode: (
    '$_blob'
        '<path d="M70 32 A30 30 0 1 0 90 74 A24 24 0 0 1 70 32 Z" '
        'fill="{tile}"/>',
    '${_sparkle(98, 26)}'
        '${_sparkle(88, 98, 5)}'
        '<circle cx="20" cy="30" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Font size: "Aa" on a card, a big letter and a small one.
  Section.fontSize: (
    '$_blob'
        '<rect x="24" y="36" width="72" height="54" rx="6" fill="{tile}"/>'
        '<path d="M34 80 L47 46 L60 80 M39.5 68 H54.5"/>'
        '<circle cx="74" cy="72" r="7.5" stroke-width="4"/>'
        '<path d="M81.5 63 V80" stroke-width="4"/>',
    '<path d="M104 30 V50 M98 36 L104 30 L110 36 M98 44 L104 50 L110 44"/>'
        '<path d="M12 98 C18 92 24 104 30 98"/>'
        '<circle cx="20" cy="28" r="3" fill="{ink}" stroke="none"/>',
  ),

  // AI translator: the four-pointed sparkle of AI, with a small one.
  Section.aiTranslator: (
    '$_blob'
        '<path d="M56 26 C60 50 66 56 90 62 C66 68 60 74 56 98 '
        'C52 74 46 68 22 62 C46 56 52 50 56 26 Z" fill="{tile}"/>'
        '<path d="M88 22 C89 30 91 32 99 33 C91 34 89 36 88 44 '
        'C87 36 85 34 77 33 C85 32 87 30 88 22 Z" fill="{tile}" '
        'stroke-width="4"/>',
    '<path d="M12 96 C18 90 24 102 30 96 C36 90 42 102 48 96"/>'
        '<circle cx="104" cy="96" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Feedback: an envelope, sent off with motion lines.
  Section.feedback: (
    '$_blob'
        '<rect x="26" y="40" width="68" height="48" rx="5" fill="{tile}"/>'
        '<path d="M28 44 L60 68 L92 44"/>',
    '<path d="M100 50 H114 M104 62 H116 M100 74 H112" stroke-width="4"/>'
        '${_sparkle(22, 26)}'
        '<path d="M14 104 C20 98 26 110 32 104"/>',
  ),

  // Chat with AI: a speech bubble with three dots and the AI sparkle.
  Section.chatAi: (
    '$_blob'
        '<path d="M32 36 H82 A10 10 0 0 1 92 46 V68 A10 10 0 0 1 82 78 H54 '
        'L40 90 L42 78 H32 A10 10 0 0 1 22 68 V46 A10 10 0 0 1 32 36 Z" '
        'fill="{tile}"/>'
        '<circle cx="42" cy="57" r="4" fill="{ink}" stroke="none"/>'
        '<circle cx="57" cy="57" r="4" fill="{ink}" stroke="none"/>'
        '<circle cx="72" cy="57" r="4" fill="{ink}" stroke="none"/>'
        '<path d="M96 14 C97 22 99 24 107 25 C99 26 97 28 96 36 '
        'C95 28 93 26 85 25 C93 24 95 22 96 14 Z" fill="{tile}" '
        'stroke-width="4"/>',
    '<path d="M12 98 C18 92 24 104 30 98"/>'
        '<circle cx="20" cy="30" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Crossword: a 3 × 3 grid of tiles, two of them black, a "C" in the
  // corner one.
  Section.crossword: (
    '$_blob'
        '<g transform="rotate(-6 60 64)">'
        '<rect x="32" y="36" width="56" height="56" rx="4" fill="{tile}"/>'
        '<path d="M50.7 36 V92 M69.3 36 V92 M32 54.7 H88 M32 73.3 H88" '
        'stroke-width="4"/>'
        '<rect x="50.7" y="36" width="18.6" height="18.7" fill="{ink}"/>'
        '<rect x="69.3" y="73.3" width="18.7" height="18.7" fill="{ink}"/>'
        '<path d="M46 42 A6 6 0 1 0 46 50" stroke-width="3.5"/>'
        '</g>',
    '${_sparkle(102, 24)}'
        '<path d="M12 98 C18 92 24 104 30 98"/>'
        '<circle cx="20" cy="30" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Find the Words: a card of letters with one word highlighted, and a
  // magnifying glass over it.
  Section.findWords: (
    '$_blob'
        '<rect x="24" y="36" width="58" height="50" rx="5" fill="{tile}"/>'
        '<rect x="30" y="54" width="46" height="13" rx="6.5" fill="{blob}" '
        'stroke="none"/>'
        '<path d="M32 46 H38 M45 46 H51 M58 46 H64 M71 46 H75 '
        'M32 60.5 H38 M45 60.5 H51 M58 60.5 H64 M71 60.5 H75 '
        'M32 76 H38 M45 76 H51 M58 76 H64 M71 76 H75" stroke-width="3.5"/>'
        '<circle cx="76" cy="70" r="13" fill="{tile}" fill-opacity="0.6"/>'
        '<path d="M85.5 79.5 L98 92" stroke-width="7"/>',
    '${_sparkle(100, 24)}'
        '<path d="M12 98 C18 92 24 104 30 98"/>'
        '<circle cx="20" cy="30" r="3" fill="{ink}" stroke="none"/>',
  ),

  // Riddles: a big hand-drawn question mark.
  Section.riddles: (
    '$_blob'
        '<path d="M46 50 C46 34 74 34 74 50 C74 62 60 62 60 74 V77" '
        'stroke-width="8"/>'
        '<circle cx="60" cy="89" r="5" fill="{ink}" stroke="none"/>',
    '${_sparkle(100, 24)}'
        '${_sparkle(22, 92, 6)}'
        '<path d="M14 34 C18 26 28 30 24 37"/>',
  ),

  // About the app: an "i" in a circle.
  Section.about: (
    '$_blob'
        '<circle cx="60" cy="62" r="28" fill="{tile}"/>'
        '<circle cx="60" cy="49" r="4" fill="{ink}" stroke="none"/>'
        '<path d="M60 59 V77 M53 77 H67 M54 59 H60"/>',
    '${_sparkle(100, 24)}'
        '<path d="M12 96 C18 90 24 102 30 96 C36 90 42 102 48 96"/>'
        '<circle cx="98" cy="98" r="3" fill="{ink}" stroke="none"/>',
  ),
};

/// A language's flag, drawn like the section icons: the country's flag
/// over the language colour's circle, with a sparkle. The flag keeps
/// its real colours in light and dark mode.
/// A language's picture: a doodled landmark of a country where it's
/// spoken (Big Ben for English, the Parthenon for Greek…) on a round blob
/// of one of the palette's colours. (Named FlagIcon from when it was a
/// flag.)
class FlagIcon extends StatelessWidget {
  final String code;
  final double size;

  const FlagIcon(this.code, {super.key, this.size = 48});

  /// Whether there's a picture for [code].
  static bool has(String code) => _landmarks.containsKey(code);

  /// The blob's colour: the palette's colours in turn, down the list.
  static Color colorOf(String code, Brightness b) {
    final colours = [
      (AppColors.coralLight, AppColors.coralDark),
      (AppColors.cornflowerLight, AppColors.cornflowerDark),
      (AppColors.marigoldLight, AppColors.marigoldDark),
      (AppColors.roseLight, AppColors.roseDark),
      (AppColors.fernLight, AppColors.fernDark),
      (AppColors.claretLight, AppColors.claretDark),
      (AppColors.clayLight, AppColors.clayDark),
    ];
    final i = _landmarks.keys.toList().indexOf(code);
    final (light, dark) = colours[(i < 0 ? 0 : i) % colours.length];
    return b.resolve(light: light, dark: dark);
  }

  @visibleForTesting
  static String svgOf(String code, Brightness b) {
    final svg =
        '$_open$_blob'
        '<g stroke-width="4">${_landmarks[code]!}</g>'
        '${_sparkle(104, 24, 6)}'
        '<path d="M80 102 C86 96 92 108 98 102"/>'
        '$_close';
    return svg
        .replaceAll('{blob}', SectionIcon._hex(colorOf(code, b)))
        .replaceAll(
          '{ink}',
          SectionIcon._hex(
            b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark),
          ),
        )
        .replaceAll(
          '{tile}',
          SectionIcon._hex(
            b.resolve(
              light: AppColors.gridCellLight,
              dark: AppColors.gridCellDark,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    svgOf(code, Theme.of(context).brightness),
    key: Key('flag-$code'),
    width: size,
    height: size,
  );
}

/// The landmarks, drawn in a 120 × 120 box over the blob (centre 60, 64).
const _landmarks = <String, String>{
  // English: Big Ben.
  'en':
      '<path d="M50 44 L60 22 L70 44 Z" fill="{tile}"/>'
      '<rect x="51" y="44" width="18" height="50" fill="{tile}"/>'
      '<circle cx="60" cy="56" r="6" stroke-width="3"/>'
      '<path d="M60 56 V52 M60 56 H63 M56 70 V88 M64 70 V88" '
      'stroke-width="2.5"/>'
      '<path d="M40 94 H80"/>',
  // Greek: the Parthenon.
  'el':
      '<path d="M30 50 L60 34 L90 50 Z" fill="{tile}"/>'
      '<rect x="32" y="50" width="56" height="6" fill="{tile}"/>'
      '<path d="M38 58 V86 M49 58 V86 M60 58 V86 M71 58 V86 M82 58 V86"/>'
      '<path d="M30 88 H90 M27 94 H93"/>',
  // Spanish: the Sagrada Família's spires.
  'es':
      '<path d="M37 94 V56 L44 32 L51 56 V94 Z" fill="{tile}"/>'
      '<path d="M69 94 V56 L76 32 L83 56 V94 Z" fill="{tile}"/>'
      '<path d="M52 94 V48 L60 22 L68 48 V94 Z" fill="{tile}"/>'
      '<circle cx="60" cy="62" r="4" stroke-width="3"/>'
      '<path d="M30 94 H90"/>',
  // German: the Brandenburg Gate.
  'de':
      '<path d="M54 40 V33 H66 V40" stroke-width="3"/>'
      '<rect x="30" y="40" width="60" height="12" fill="{tile}"/>'
      '<path d="M36 54 V88 M45 54 V88 M54 54 V88 M66 54 V88 M75 54 V88 '
      'M84 54 V88"/>'
      '<path d="M28 90 H92"/>',
  // Italian: the Leaning Tower of Pisa.
  'it':
      '<g transform="rotate(8 60 94)">'
      '<rect x="48" y="30" width="24" height="64" rx="2" fill="{tile}"/>'
      '<path d="M48 40 H72 M48 51 H72 M48 62 H72 M48 73 H72 M48 84 H72" '
      'stroke-width="2.5"/>'
      '<rect x="51" y="24" width="18" height="6" fill="{tile}"/>'
      '</g>'
      '<path d="M36 96 H84"/>',
  // French: the Eiffel Tower.
  'fr':
      '<path d="M60 20 L69 58 L80 94 H70 C68 84 52 84 50 94 H40 L51 58 Z" '
      'fill="{tile}"/>'
      '<path d="M50 58 H70 M46 74 H74" stroke-width="3"/>'
      '<path d="M36 94 H84"/>',
  // Russian: onion domes.
  'ru':
      '<path d="M48 60 C42 52 50 42 60 34 C70 42 78 52 72 60 Z" '
      'fill="{tile}"/>'
      '<path d="M60 34 V24"/>'
      '<path d="M30 70 C27 64 32 58 37 54 C42 58 47 64 44 70 Z" '
      'fill="{tile}"/>'
      '<path d="M76 70 C73 64 78 58 83 54 C88 58 93 64 90 70 Z" '
      'fill="{tile}"/>'
      '<rect x="31" y="70" width="12" height="24" fill="{tile}"/>'
      '<rect x="77" y="70" width="12" height="24" fill="{tile}"/>'
      '<rect x="47" y="60" width="26" height="34" fill="{tile}"/>'
      '<path d="M26 94 H94"/>',
  // Portuguese: the Belém Tower.
  'pt':
      '<rect x="46" y="42" width="28" height="52" fill="{tile}"/>'
      '<path d="M46 42 V35 H51 V42 M56 42 V35 H64 V42 M69 42 V35 H74 V42" '
      'stroke-width="3"/>'
      '<path d="M55 94 V82 C55 76 65 76 65 82 V94" stroke-width="3"/>'
      '<path d="M54 56 H66 M54 66 H66" stroke-width="3"/>'
      '<path d="M34 94 H86"/>',
  // Dutch: a windmill.
  'nl':
      '<path d="M50 94 L54 54 H66 L70 94 Z" fill="{tile}"/>'
      '<path d="M52 54 Q60 44 68 54"/>'
      '<path d="M60 48 L36 26 M60 48 L84 26 M60 48 L38 72 M60 48 L82 72"/>'
      '<circle cx="60" cy="48" r="3" fill="{ink}" stroke="none"/>'
      '<path d="M38 94 H82"/>',
  // Polish: the Palace of Culture.
  'pl':
      '<path d="M42 94 V68 H49 V54 H54 V42 H57 L60 20 L63 42 H66 V54 H71 '
      'V68 H78 V94 Z" fill="{tile}"/>'
      '<path d="M54 62 H66 M54 76 H66" stroke-width="3"/>'
      '<path d="M32 94 H88"/>',
  // Turkish: a mosque with its minarets.
  'tr':
      '<path d="M42 62 C42 44 78 44 78 62 Z" fill="{tile}"/>'
      '<rect x="40" y="62" width="40" height="30" fill="{tile}"/>'
      '<path d="M28 92 V42 L31 32 L34 42 V92 M86 92 V42 L89 32 L92 42 V92" '
      'stroke-width="3.5"/>'
      '<path d="M60 47 V38" stroke-width="3"/>'
      '<path d="M24 94 H96"/>',
  // Swedish: a Dala horse.
  'sv':
      '<path d="M40 92 V72 C34 68 34 60 40 56 L46 42 C49 36 57 37 58 43 '
      'L60 50 H78 C84 50 86 56 84 62 L86 92 H77 V76 H49 V92 Z" '
      'fill="{tile}"/>'
      '<path d="M54 60 C58 66 66 66 70 60" stroke-width="3"/>'
      '<circle cx="50" cy="48" r="2" fill="{ink}" stroke="none"/>',
  // Norwegian: a stave church.
  'no':
      '<rect x="44" y="74" width="32" height="20" fill="{tile}"/>'
      '<path d="M38 74 L60 60 L82 74 Z" fill="{tile}"/>'
      '<path d="M45 60 L60 48 L75 60 Z" fill="{tile}"/>'
      '<path d="M51 48 L60 30 L69 48 Z" fill="{tile}"/>'
      '<path d="M60 30 V22" stroke-width="3"/>'
      '<path d="M34 94 H86"/>',
  // Danish: the Little Mermaid on her rock.
  'da':
      '<path d="M32 94 C34 80 86 80 88 94 Z" fill="{tile}"/>'
      '<circle cx="56" cy="46" r="7" fill="{tile}"/>'
      '<path d="M56 53 C48 62 50 74 62 80 C70 83 76 80 80 74"/>'
      '<path d="M50 62 L62 66"/>',
  // Finnish: Helsinki Cathedral.
  'fi':
      '<path d="M50 52 C50 38 70 38 70 52 Z" fill="{tile}"/>'
      '<rect x="48" y="52" width="24" height="10" fill="{tile}"/>'
      '<path d="M36 70 L60 60 L84 70 Z" fill="{tile}"/>'
      '<rect x="38" y="70" width="44" height="24" fill="{tile}"/>'
      '<path d="M46 74 V90 M56 74 V90 M64 74 V90 M74 74 V90" '
      'stroke-width="2.5"/>'
      '<path d="M60 38 V30" stroke-width="3"/>',
  // Czech: a tower of Prague's Charles Bridge.
  'cs':
      '<path d="M46 46 L60 22 L74 46 Z" fill="{tile}"/>'
      '<rect x="48" y="46" width="24" height="40" fill="{tile}"/>'
      '<path d="M54 86 V74 C54 66 66 66 66 74 V86" stroke-width="3"/>'
      '<path d="M26 92 C32 82 42 82 48 92 M72 92 C78 82 88 82 94 92"/>',
  // Hungarian: the Parliament in Budapest.
  'hu':
      '<path d="M48 64 C48 48 72 48 72 64 Z" fill="{tile}"/>'
      '<path d="M60 50 V34" stroke-width="3"/>'
      '<rect x="28" y="64" width="64" height="28" fill="{tile}"/>'
      '<path d="M32 64 V52 M88 64 V52" stroke-width="3"/>'
      '<path d="M36 72 V86 M46 72 V86 M74 72 V86 M84 72 V86" '
      'stroke-width="2.5"/>',
  // Romanian: Bran Castle.
  'ro':
      '<rect x="44" y="56" width="32" height="38" fill="{tile}"/>'
      '<rect x="32" y="50" width="14" height="44" fill="{tile}"/>'
      '<rect x="74" y="50" width="14" height="44" fill="{tile}"/>'
      '<path d="M30 50 L39 32 L48 50 Z" fill="{tile}"/>'
      '<path d="M72 50 L81 32 L90 50 Z" fill="{tile}"/>'
      '<path d="M54 94 V82 C54 76 66 76 66 82 V94" stroke-width="3"/>',
  // Ukrainian: a sunflower.
  'uk':
      '<path d="M60 74 V96 M60 86 C52 80 46 84 44 88" stroke-width="4"/>'
      '<g fill="{tile}">'
      '<ellipse cx="60" cy="32" rx="6" ry="10"/>'
      '<ellipse cx="60" cy="68" rx="6" ry="10"/>'
      '<ellipse cx="42" cy="50" rx="10" ry="6"/>'
      '<ellipse cx="78" cy="50" rx="10" ry="6"/>'
      '<ellipse cx="47" cy="37" rx="6" ry="10" transform="rotate(-45 47 37)"/>'
      '<ellipse cx="73" cy="37" rx="6" ry="10" transform="rotate(45 73 37)"/>'
      '<ellipse cx="47" cy="63" rx="6" ry="10" transform="rotate(45 47 63)"/>'
      '<ellipse cx="73" cy="63" rx="6" ry="10" transform="rotate(-45 73 63)"/>'
      '</g>'
      '<circle cx="60" cy="50" r="9" fill="{ink}" stroke="none"/>',
  // Japanese: a torii gate.
  'ja':
      '<path d="M28 38 C48 45 72 45 92 38" stroke-width="6"/>'
      '<path d="M36 52 H84" stroke-width="5"/>'
      '<path d="M44 42 V94 M76 42 V94" stroke-width="6"/>'
      '<path d="M60 44 V52" stroke-width="4"/>',
  // Chinese: a pagoda.
  'zh':
      '<path d="M36 52 Q60 40 84 52 Z" fill="{tile}"/>'
      '<rect x="46" y="52" width="28" height="10" fill="{tile}"/>'
      '<path d="M30 72 Q60 58 90 72 Z" fill="{tile}"/>'
      '<rect x="42" y="72" width="36" height="22" fill="{tile}"/>'
      '<path d="M60 41 V28" stroke-width="3"/>'
      '<path d="M34 94 H86"/>',
  // Korean: Namdaemun, Seoul's old gate.
  'ko':
      '<path d="M40 50 Q60 36 80 50 Z" fill="{tile}"/>'
      '<rect x="44" y="50" width="32" height="10" fill="{tile}"/>'
      '<path d="M30 62 Q60 48 90 62 Z" fill="{tile}"/>'
      '<rect x="34" y="66" width="52" height="28" fill="{tile}"/>'
      '<path d="M54 94 V84 C54 78 66 78 66 84 V94" stroke-width="3"/>',
  // Arabic: the pyramids.
  'ar':
      '<path d="M28 92 L54 46 L80 92 Z" fill="{tile}"/>'
      '<path d="M66 92 L80 68 L94 92 Z" fill="{tile}"/>'
      '<path d="M54 46 L60 92" stroke-width="2.5"/>'
      '<path d="M24 94 H96"/>',
  // Hindi: the Taj Mahal.
  'hi':
      '<path d="M46 58 C40 44 52 34 60 26 C68 34 80 44 74 58 Z" '
      'fill="{tile}"/>'
      '<rect x="40" y="58" width="40" height="34" fill="{tile}"/>'
      '<path d="M54 92 V78 C54 70 66 70 66 78 V92" stroke-width="3"/>'
      '<path d="M30 92 V52 M90 92 V52" stroke-width="3.5"/>'
      '<circle cx="30" cy="49" r="3" fill="{ink}" stroke="none"/>'
      '<circle cx="90" cy="49" r="3" fill="{ink}" stroke="none"/>'
      '<path d="M26 94 H94"/>',
  // Vietnamese: a conical hat.
  'vi':
      '<path d="M26 80 L60 38 L94 80 Q60 90 26 80 Z" fill="{tile}"/>'
      '<path d="M43 59 Q60 66 77 59 M35 70 Q60 78 85 70" '
      'stroke-width="2.5"/>'
      '<path d="M44 84 C50 96 70 96 76 84" stroke-width="2.5"/>',
};
