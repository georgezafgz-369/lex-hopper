// ─────────────────────────────────────────────────────────────────────────────
// LEX HOPPER — DESIGN SYSTEM
// ─────────────────────────────────────────────────────────────────────────────
//
// Source of truth for all colours, typography, spacing, states, and tone.
// Every widget in this app references values from this file only.
//
// Principles (from the design package, docs/design-package.pdf):
//   1. The puzzle is the hero. Chrome stays quiet.
//   2. Printed-paper feel — warm paper, ink-black type, thin rules.
//   3. Warm, not childish. Earthy colours, dry humour. No neon, no mascots.
//   4. Rewarding without pressure. Progress is celebrated softly.
//
// Palette rule of thumb: ~85 % paper & ink, 10 % clay, 5 % olive or claret.
// ─────────────────────────────────────────────────────────────────────────────

library;

import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

// ──────────────────────────────────────────────────────────────────────────────
// COLOURS
// ──────────────────────────────────────────────────────────────────────────────

/// Semantic colour roles. Light and dark variants for every token.
class AppColors {
  AppColors._();

  // ── Surfaces ────────────────────────────────────────────────────────────
  static const paperLight = Color(0xFFF5E6D3);
  static const paperDark = Color(0xFF1B1815);

  static const gridCellLight = Color(0xFFFFFFFF);
  static const gridCellDark = Color(0xFF26221C);

  // Crossword grid cells — white, with darker border for visibility
  static const crosswordCellLight = Color(0xFFFFFFFF);
  static const crosswordCellDark = Color(0xFF2E2A24);

  // Crossword grid cell border — darker for contrast
  static const crosswordCellBorderLight = Color(0xFF8A7F72);
  static const crosswordCellBorderDark = Color(0xFF6B6258);

  // ── Type ────────────────────────────────────────────────────────────────
  static const inkLight = Color(0xFF201B17);
  static const inkDark = Color(0xFFF1E9DD);

  static const mutedLight = Color(0xFF6B6258);
  static const mutedDark = Color(0xFFA39A8D);

  // ── Rules ───────────────────────────────────────────────────────────────
  static const hairlineLight = Color(0xFFCFC2AE);
  static const hairlineDark = Color(0xFF4A4338);

  // ── Brand accents ───────────────────────────────────────────────────────
  static const clayLight = Color(0xFFC8613F);
  static const clayDark = Color(0xFFE08A66);

  static const oliveLight = Color(0xFF3F5A3C);
  static const oliveDark = Color(0xFF8FDB0A);

  // Secondary-language translations: a bright orange, so translations
  // stand apart from the main text and from the clay accent.
  static const translationLight = Color(0xFFE8761E);
  static const translationDark = Color(0xFFF59A4A);

  static const claretLight = Color(0xFF8F1D3F);
  static const claretDark = Color(0xFFD4637F);

  // ── Crossword / puzzle states ──────────────────────────────────────────
  static const selectedCellLight = Color(0xFFF2B89F);
  static const selectedCellDark = Color(0xFF7A4A36);

  static const currentWordLight = Color(0xFFFBE2D2);
  static const currentWordDark = Color(0xFF4A3328);

  static const checkedCorrectLight = Color(0xFFDCE6D5);
  static const checkedCorrectDark = Color(0xFF2F3F2D);

  static const checkedWrongLight = Color(0xFFF2D4DC);
  static const checkedWrongDark = Color(0xFF512431);

  // ── Word-search highlighter tints ──────────────────────────────────────
  static const wsClay = Color(0xFFFC9B98);
  static const wsOlive = Color(0xFFD5E3CC);
  static const wsOchre = Color(0xFFF1DDA6);
  static const wsSlate = Color(0xFFD3DDEA);
  static const wsPlum = Color(0xFFE4D0E0);

  static const wordSearchMarkers = <Color>[
    wsClay,
    wsOlive,
    wsOchre,
    wsSlate,
    wsPlum,
  ];

  // ── Section colours ────────────────────────────────────────────────────
  // Bright, flat colours behind each section's doodle icon (SectionIcon),
  // warmed a little to sit on the paper. Dark variants are deeper, so the
  // light doodle lines of dark mode stay readable on them.
  static const coralLight = Color(0xFFEC6A55); // Games
  static const coralDark = Color(0xFFC4523F);
  static const cornflowerLight = Color(0xFF5B86DB); // Dictionary
  static const cornflowerDark = Color(0xFF3F67B5);
  static const marigoldLight = Color(0xFFEFA834); // Translator
  static const marigoldDark = Color(0xFFC88620);
  static const roseLight = Color(0xFFEFA3C8); // Settings
  static const roseDark = Color(0xFFB86F95);
  static const fernLight = Color(0xFF3DAE63); // spare (e.g. word of the day)
  static const fernDark = Color(0xFF2E8A4D);
}

// ──────────────────────────────────────────────────────────────────────────────
// THEME
// ──────────────────────────────────────────────────────────────────────────────

/// Resolve a light/dark token for the current brightness.
extension ColorResolver on Brightness {
  Color resolve({required Color light, required Color dark}) =>
      (name == 'light') ? light : dark;
}

ThemeData lexTheme({required Brightness brightness}) {
  final isLight = brightness == Brightness.light;
  final paper = isLight ? AppColors.paperLight : AppColors.paperDark;
  final ink = isLight ? AppColors.inkLight : AppColors.inkDark;
  final hairline = isLight ? AppColors.hairlineLight : AppColors.hairlineDark;
  final clay = isLight ? AppColors.clayLight : AppColors.clayDark;
  final olive = isLight ? AppColors.oliveLight : AppColors.oliveDark;

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: paper,
    primaryColor: clay,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: clay,
      onPrimary: isLight ? Colors.white : AppColors.paperDark,
      secondary: olive,
      onSecondary: isLight ? Colors.white : AppColors.paperDark,
      surface: paper,
      onSurface: ink,
      error: isLight ? AppColors.claretLight : AppColors.claretDark,
      onError: isLight ? Colors.white : AppColors.paperDark,
    ),
    textTheme: _textTheme(brightness),
    dividerTheme: DividerThemeData(color: hairline, thickness: 0.5),
    cardTheme: CardThemeData(
      color: isLight ? AppColors.gridCellLight : AppColors.gridCellDark,
      elevation: 0, // almost no shadows
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radius.sm),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight ? AppColors.gridCellLight : AppColors.gridCellDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radius.sm),
        borderSide: BorderSide(color: hairline, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radius.sm),
        borderSide: BorderSide(color: hairline, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radius.sm),
        borderSide: BorderSide(color: clay, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: clay,
        foregroundColor: isLight ? Colors.white : AppColors.paperDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radius.sm),
        ),
        minimumSize: const Size(88, 36),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: clay,
        minimumSize: const Size(88, 36),
      ),
    ),
    iconTheme: IconThemeData(color: ink, size: 20),
    // No shadows on floating buttons — keep it printed
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: clay,
      foregroundColor: isLight ? Colors.white : AppColors.paperDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radius.sm),
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY
// ──────────────────────────────────────────────────────────────────────────────
//
// Clues, headlines & long reading → Tinos (free, Times New Roman's
// shapes and widths, with Greek letters). Was Source Serif 4, which has
// no Greek: switch back by using sourceSerif4TextTheme() below.
// Grid letters & UI → Inter (semibold capitals for grid)
// Scale: 12 / 14 / 16 / 20 / 28 / 40
// Body line-height ≈ 1.5
//

TextTheme _textTheme(Brightness brightness) {
  final ink = brightness == Brightness.light
      ? AppColors.inkLight
      : AppColors.inkDark;
  final muted = brightness == Brightness.light
      ? AppColors.mutedLight
      : AppColors.mutedDark;

  final serif = GoogleFonts.tinosTextTheme();
  final sans = GoogleFonts.interTextTheme();
  // Each style below is passed through GoogleFonts again with its final
  // weight: the font file is picked when a style is made, so only changing
  // fontWeight afterwards would keep the regular file (no real bold).

  return TextTheme(
    // ── Headlines (Tinos) ──────────────────────────────────────────
    displayLarge: GoogleFonts.tinos(
      textStyle: serif.displayLarge?.copyWith(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.3,
      ),
    ),
    displayMedium: GoogleFonts.tinos(
      textStyle: serif.displayMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.3,
      ),
    ),
    displaySmall: GoogleFonts.tinos(
      textStyle: serif.displaySmall?.copyWith(
        fontSize: 20,
        // Bold: Tinos has no semi-bold (w600 would fall back to regular).
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.4,
      ),
    ),
    headlineMedium: GoogleFonts.tinos(
      textStyle: serif.headlineMedium?.copyWith(
        fontSize: 20,
        // Bold: Tinos has no semi-bold (w600 would fall back to regular).
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.4,
      ),
    ),

    // ── Body & clues (Tinos) ──────────────────────────────────────
    bodyLarge: GoogleFonts.tinos(
      textStyle: serif.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.5,
      ),
    ),
    bodyMedium: GoogleFonts.tinos(
      textStyle: serif.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.5,
      ),
    ),
    bodySmall: GoogleFonts.tinos(
      textStyle: serif.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: muted,
        height: 1.5,
      ),
    ),

    // ── UI / grid (Inter) ───────────────────────────────────────────────
    labelLarge: GoogleFonts.inter(
      textStyle: sans.labelLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    labelMedium: GoogleFonts.inter(
      textStyle: sans.labelMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
    labelSmall: GoogleFonts.inter(
      textStyle: sans.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
      ),
    ),
  );
}

/// Small uppercase kicker — "DAILY CROSSWORD" / "NO. 142"
TextStyle kickerStyle({required Brightness brightness}) {
  final muted = brightness == Brightness.light
      ? AppColors.mutedLight
      : AppColors.mutedDark;
  return GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: muted,
    letterSpacing: 1.5,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// SPACING  (8-pt grid)
// ──────────────────────────────────────────────────────────────────────────────

class Spacing {
  Spacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

// ──────────────────────────────────────────────────────────────────────────────
// BORDER RADIUS
// ──────────────────────────────────────────────────────────────────────────────
// Cards and buttons have softly rounded corners (8 px). The crossword grid
// squares keep tiny 1 px corners so the grid still looks printed.

class Radius {
  Radius._();
  static const none = 0.0;
  static const sm = 8.0; // cards, buttons, search bars
  static const md = 8.0;
  static const lg = 16.0; // bottom sheets (top corners)
}

/// Reusable home button — one tap goes back to HomePage.
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final clay = brightness.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );

    return GestureDetector(
      key: const Key('home-button'),
      onTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: clay,
          borderRadius: BorderRadius.circular(Radius.sm),
        ),
        child: Icon(
          Icons.home_outlined,
          size: 20,
          color: brightness == Brightness.light
              ? Colors.white
              : AppColors.paperDark,
        ),
      ),
    );
  }
}
