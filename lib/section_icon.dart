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
  // The bottom menu's open / close button.
  menu,
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
    Section.menu => b.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
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

  // The bottom menu's button: three thick lines.
  Section.menu: (
    '$_blob'
        '<path d="M38 48 H82 M38 64 H82 M38 80 H82" stroke-width="7"/>',
    '${_sparkle(100, 22)}'
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
class FlagIcon extends StatelessWidget {
  /// The language code: en, el, es, fr, de, it.
  final String code;
  final double size;

  const FlagIcon(this.code, {super.key, this.size = 48});

  /// Whether there's a flag for [code].
  static bool has(String code) => _flags.containsKey(code);

  @visibleForTesting
  static String svgOf(String code, Brightness b) {
    const flagArea = 'x="34" y="34" width="62" height="42" rx="4"';
    final svg =
        '$_open$_blob'
        // The flag on its own, centred on the circle: its colours clipped
        // to a rounded card, outlined.
        '<g transform="translate(-5 9)">'
        '<clipPath id="f"><rect $flagArea/></clipPath>'
        '<g clip-path="url(#f)" stroke="none">${_flags[code]!}</g>'
        '<rect $flagArea/>'
        '</g>'
        '${_sparkle(104, 24, 6)}'
        '<path d="M78 98 C84 92 90 104 96 98"/>'
        '$_close';
    return svg
        .replaceAll(
          '{blob}',
          SectionIcon._hex(SectionIcon.colorOf(Section.language, b)),
        )
        .replaceAll(
          '{ink}',
          SectionIcon._hex(
            b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark),
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

/// Horizontal stripes over the flag's area (y 34–76), top to bottom.
String _stripes(List<String> colours) {
  final h = 42 / colours.length;
  return [
    for (final (i, c) in colours.indexed)
      '<rect x="34" y="${34 + i * h}" width="62" height="${h + 0.5}" '
          'fill="$c"/>',
  ].join();
}

/// Vertical stripes over the flag's area (x 34–96), left to right.
String _bands(List<String> colours) {
  final w = 62 / colours.length;
  return [
    for (final (i, c) in colours.indexed)
      '<rect x="${34 + i * w}" y="34" width="${w + 0.5}" height="42" '
          'fill="$c"/>',
  ].join();
}

const _white = '#FFFFFF';
const _greekBlue = '#0D5EAF';

final _flags = <String, String>{
  // United Kingdom: the Union Jack.
  'en':
      '<rect x="34" y="34" width="62" height="42" fill="#012169"/>'
      '<path d="M34 34 L96 76 M96 34 L34 76" stroke="$_white" '
      'stroke-width="9"/>'
      '<path d="M34 34 L96 76 M96 34 L34 76" stroke="#C8102E" '
      'stroke-width="3"/>'
      '<rect x="34" y="49" width="62" height="12" fill="$_white"/>'
      '<rect x="59" y="34" width="12" height="42" fill="$_white"/>'
      '<rect x="34" y="51.5" width="62" height="7" fill="#C8102E"/>'
      '<rect x="61.5" y="34" width="7" height="42" fill="#C8102E"/>',
  // Greece: nine blue and white stripes, a white cross on blue.
  'el':
      '${_stripes([for (var i = 0; i < 9; i++) i.isEven ? _greekBlue : _white])}'
      '<rect x="34" y="34" width="23.3" height="23.3" fill="$_greekBlue"/>'
      '<rect x="34" y="43" width="23.3" height="4.7" fill="$_white"/>'
      '<rect x="43.3" y="34" width="4.7" height="23.3" fill="$_white"/>',
  // Spain: red, a wide yellow band, red.
  'es': _stripes(['#AA151B', '#F1BF00', '#F1BF00', '#AA151B']),
  // France: blue, white, red.
  'fr': _bands(['#0055A4', _white, '#EF4135']),
  // Germany: black, red, gold.
  'de': _stripes(['#000000', '#DD0000', '#FFCE00']),
  // Italy: green, white, red.
  'it': _bands(['#009246', _white, '#CE2B37']),
};
