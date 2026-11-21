// ─────────────────────────────────────────────────────────────────────────────
// GAMES PAGE — every game, one card each (opened from the home Games card)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'dual_text.dart';
import 'design_system.dart';
import 'dictionary_search_bar.dart';
import 'menu_card.dart';

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
                    child: DictionarySearchBar(fieldKey: Key('games-search')),
                  ),
                  const SizedBox(width: Spacing.sm),
                  const HomeButton(),
                ],
              ),
            ),

            // ── Games ─────────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: Spacing.sm),
                    DualText(
                      (t) => t.games,
                      style: kickerStyle(brightness: brightness),
                      inline: true,
                    ),
                    const SizedBox(height: Spacing.sm),
                    MenuCard(
                      title: (t) => t.crossword,
                      subtitle: (t) => t.crosswordSubtitle,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/crossword'),
                    ),
                    const SizedBox(height: Spacing.md),
                    MenuCard(
                      title: (t) => t.findTheWords,
                      subtitle: (t) => t.findTheWordsSubtitle,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/word-search'),
                    ),
                    const SizedBox(height: Spacing.md),
                    MenuCard(
                      title: (t) => t.riddles,
                      subtitle: (t) => t.riddlesSubtitle,
                      comingSoon: true,
                      onTap: () {},
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
