// ─────────────────────────────────────────────────────────────────────────────
// GAMES PAGE — every game, one card each (opened from the home Games card)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'app_text.dart';
import 'dual_text.dart';
import 'section_icon.dart';
import 'design_system.dart';
import 'dictionary_search_bar.dart';

class GamesPage extends StatelessWidget {
  const GamesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = brightness.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final gridCell = brightness.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    key: const Key('games-back'),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: gridCell,
                        borderRadius: BorderRadius.circular(Radius.sm),
                      ),
                      child: Icon(Icons.arrow_back, size: 20, color: ink),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // Dictionary search, in the middle.
                  const Expanded(
                    child: DictionarySearchToggle(
                      fieldKey: Key('games-search'),
                    ),
                  ),
                ],
              ),
            ),

            // ── Games ─────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  0,
                  Spacing.md,
                  Spacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Spacing.sm),
                    // The page's title, big and bold.
                    DualText(
                      (t) => t.games,
                      style: Theme.of(context).textTheme.displayLarge,
                      inline: true,
                    ),
                    const SizedBox(height: Spacing.sm),
                    // The three games side by side, as small tiles.
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _GameTile(
                              key: const Key('game-crossword'),
                              section: Section.crossword,
                              title: (t) => t.crossword,
                              onTap: () =>
                                  Navigator.of(context).pushNamed('/crossword'),
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: _GameTile(
                              key: const Key('game-find-the-words'),
                              section: Section.findWords,
                              title: (t) => t.findTheWords,
                              onTap: () =>
                                  Navigator.of(context)
                                      .pushNamed('/word-search'),
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          const Expanded(
                            child: _GameTile(
                              key: Key('game-riddles'),
                              section: Section.riddles,
                              title: _riddles,
                              comingSoon: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _riddles(AppText t) => t.riddles;

/// A game as a small square tile: its doodle on top, its name under it,
/// and "Coming soon" (faded, not tappable) when it isn't ready.
class _GameTile extends StatelessWidget {
  final Section section;
  final TextPick title;
  final VoidCallback? onTap;
  final bool comingSoon;

  const _GameTile({
    super.key,
    required this.section,
    required this.title,
    this.onTap,
    this.comingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final muted = b.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    return GestureDetector(
      onTap: comingSoon ? null : onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xs,
          Spacing.md,
          Spacing.xs,
          Spacing.md,
        ),
        decoration: BoxDecoration(
          color: b.resolve(
            light: AppColors.gridCellLight,
            dark: AppColors.gridCellDark,
          ),
          borderRadius: BorderRadius.circular(Radius.sm),
          border: Border.all(
            color: b.resolve(
              light: AppColors.hairlineLight,
              dark: AppColors.hairlineDark,
            ),
            width: 0.5,
          ),
        ),
        child: Opacity(
          opacity: comingSoon ? 0.6 : 1,
          child: Column(
            children: [
              SectionIcon(section, size: 72),
              const SizedBox(height: Spacing.sm),
              DualText(
                title,
                style: Theme.of(context).textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              if (comingSoon) ...[
                const SizedBox(height: 4),
                DualText(
                  (t) => t.comingSoon,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: muted,
                    fontFamily: 'Inter',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
