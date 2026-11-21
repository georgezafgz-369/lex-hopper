// ─────────────────────────────────────────────────────────────────────────────
// SUBJECT PICKER — shown after New Game in both games
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'design_system.dart';
import 'dictionary_service.dart';
import 'dual_text.dart';
import 'puzzle_themes.dart';
import 'word_sheet.dart' show showDraggableSheet;

/// A theme is offered only when it has at least this many answers in the
/// game's language (fewer would repeat words too soon). English has all 18;
/// Greek has the 9 biggest (its dictionary is much smaller).
const minThemeWords = 60;

/// What the player chose: [theme] null means "All subjects".
class ThemeChoice {
  final PuzzleTheme? theme;
  const ThemeChoice(this.theme);
}

/// The list of subjects for a new game in [language]: "All subjects" first,
/// then the themes with enough words. Null if closed without choosing.
Future<ThemeChoice?> showThemePicker(
  BuildContext context, {
  required String language,
}) async {
  final service = DictionaryService.forLanguage(language);
  final sizes = <PuzzleTheme, int>{
    for (final t in puzzleThemes) t: await service.themeSize(t.id),
  };
  if (!context.mounted) return null;
  ThemeChoice? chosen;
  await showDraggableSheet(
    context,
    builder: (scrollController) => _ThemeList(
      scrollController: scrollController,
      themes: [
        for (final t in puzzleThemes)
          if (sizes[t]! >= minThemeWords) (t, sizes[t]!),
      ],
      onPick: (choice) => chosen = choice,
    ),
  );
  return chosen;
}

class _ThemeList extends StatelessWidget {
  final ScrollController scrollController;
  final List<(PuzzleTheme, int)> themes;
  final void Function(ThemeChoice) onPick;

  const _ThemeList({
    required this.scrollController,
    required this.themes,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );

    void pick(PuzzleTheme? theme) {
      onPick(ThemeChoice(theme));
      Navigator.of(context).pop();
    }

    Widget row({
      required Key key,
      required TextPick title,
      required TextPick subtitle,
      required VoidCallback onTap,
    }) {
      return InkWell(
        key: key,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: hairline, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DualText(
                title,
                inline: true,
                style: TextStyle(fontSize: 17, fontFamily: 'Inter', color: ink),
              ),
              const SizedBox(height: 2),
              DualText(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Inter',
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.xl),
      children: [
        DualText(
          (t) => t.chooseSubject,
          inline: true,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: Spacing.sm),
        row(
          key: const Key('theme-all'),
          title: (t) => t.allThemes,
          subtitle: (t) => t.allSubjectsSubtitle,
          onTap: () => pick(null),
        ),
        for (final (theme, count) in themes)
          row(
            key: Key('theme-${theme.id}'),
            title: theme.name,
            subtitle: (t) => t.wordCount(count),
            onTap: () => pick(theme),
          ),
      ],
    );
  }
}
