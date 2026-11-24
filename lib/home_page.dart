// ─────────────────────────────────────────────────────────────────────────────
// HOME PAGE — "The Puzzle Page"
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'bottom_menu.dart';
import 'dual_text.dart';
import 'design_system.dart';
import 'section_icon.dart';
import 'dictionary_search_bar.dart';
import 'language_button.dart';
import 'menu_card.dart';
import 'word_of_the_day_card.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = brightness.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );

    return Scaffold(
      backgroundColor: paper,
      body: BottomMenu(
        current: Section.home,
        child: SafeArea(
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DictionarySearchBar(
                        fieldKey: const Key('home-search'),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    // Translator, sliding up from the bottom.
                    const TranslateButton(),
                    const SizedBox(width: Spacing.sm),
                    // Languages: the same list as Settings > Language.
                    const LanguageButton(),
                  ],
                ),
              ),

              // ── Scrollable content ────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.md,
                    0,
                    Spacing.md,
                    BottomMenu.space, // clear of the bottom menu
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: Spacing.sm),

                      // ── Dictionary, with the Word of the Day inside ───────
                      MenuCard(
                        key: const Key('dictionary-card'),
                        leading: const SectionIcon(Section.dictionary),
                        title: (t) => t.dictionary,
                        subtitle: (t) => t.dictionarySubtitle,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/dictionary'),
                        below: const WordOfTheDayCard(embedded: true),
                      ),
                      const SizedBox(height: Spacing.md),

                      MenuCard(
                        key: const Key('translator-card'),
                        leading: const SectionIcon(Section.translator),
                        title: (t) => t.translator,
                        subtitle: (t) => t.translatorSubtitle,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/translator'),
                      ),
                      const SizedBox(height: Spacing.md),

                      // ── Games: one card that opens the Games page ─────────
                      MenuCard(
                        key: const Key('games-card'),
                        leading: const SectionIcon(Section.games),
                        title: (t) => t.gamesTitle,
                        subtitle: (t) => t.gamesList,
                        chevron: true,
                        onTap: () => Navigator.of(context).pushNamed('/games'),
                      ),
                      const SizedBox(height: Spacing.lg),

                      // ── Separator ─────────────────────────────────────────
                      Divider(color: hairline, height: 0),
                      const SizedBox(height: Spacing.lg),

                      // ── Other section ─────────────────────────────────────
                      DualText(
                        (t) => t.other,
                        style: kickerStyle(brightness: brightness),
                        inline: true,
                      ),
                      const SizedBox(height: Spacing.sm),

                      MenuCard(
                        leading: const SectionIcon(Section.settings),
                        title: (t) => t.settings,
                        subtitle: (t) => t.settingsSubtitle,
                        onTap: () =>
                            Navigator.of(context).pushNamed('/settings'),
                      ),
                      const SizedBox(height: Spacing.xxl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
