// ─────────────────────────────────────────────────────────────────────────────
// SECTION ICONS — a doodle for each part of the app (Games, Dictionary,
// Translator, Settings, and Home and Language for the menu): thick ink lines
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

enum Section { games, dictionary, translator, settings, home, language }

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
    Section.settings || Section.language => b.resolve(
      light: AppColors.roseLight,
      dark: AppColors.roseDark,
    ),
    Section.home => b.resolve(
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
};
