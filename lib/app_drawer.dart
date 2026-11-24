// ─────────────────────────────────────────────────────────────────────────────
// APP DRAWER — the side menu opened by the ☰ button on the home page, laid
// out like the home page: Home; Games with its games; Dictionary and
// Translator; Settings and Language — each with its coloured icon.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'dual_text.dart';
import 'design_system.dart';
import 'section_icon.dart';
import 'settings_page.dart' show showLanguagePicker;
import 'translator_page.dart' show showTranslatorSheet;

/// The ☰ button that opens the [AppDrawer] of the enclosing Scaffold.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      key: const Key('menu-button'),
      onTap: () => Scaffold.of(context).openDrawer(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: brightness.resolve(
            light: AppColors.gridCellLight,
            dark: AppColors.gridCellDark,
          ),
          borderRadius: BorderRadius.circular(Radius.sm),
          border: Border.all(
            color: brightness.resolve(
              light: AppColors.hairlineLight,
              dark: AppColors.hairlineDark,
            ),
            width: 0.5,
          ),
        ),
        child: Icon(
          Icons.menu,
          size: 20,
          color: brightness.resolve(
            light: AppColors.inkLight,
            dark: AppColors.inkDark,
          ),
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = brightness.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );

    /// Closes the drawer, then opens [route] (Home just closes it).
    void go(String route) {
      final navigator = Navigator.of(context);
      navigator.pop();
      if (route != '/') navigator.pushNamed(route);
    }

    /// Closes the drawer, then opens a sheet from the navigator, which
    /// stays.
    void sheet(void Function(BuildContext) open) {
      final navigator = Navigator.of(context);
      navigator.pop();
      open(navigator.context);
    }

    // The same sections as the home page, each on a card like its cards.
    return Drawer(
      key: const Key('app-drawer'),
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.md,
            Spacing.md,
            Spacing.xl,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.sm,
                Spacing.sm,
                Spacing.sm,
                Spacing.lg,
              ),
              child: Text(
                'Lex Hopper',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            _card(context, [
              _item(
                context,
                section: Section.home,
                label: (t) => t.home,
                onTap: () => go('/'),
              ),
            ]),
            const SizedBox(height: Spacing.md),
            _card(context, [
              _item(
                context,
                section: Section.games,
                label: (t) => t.gamesTitle,
                onTap: () => go('/games'),
              ),
              _game(context, (t) => t.crossword, () => go('/crossword')),
              _game(context, (t) => t.findTheWords, () => go('/word-search')),
              _game(context, (t) => t.riddles, null),
              const SizedBox(height: Spacing.sm),
            ]),
            _kicker(context, (t) => t.reference),
            _card(context, [
              _item(
                context,
                section: Section.dictionary,
                label: (t) => t.dictionary,
                onTap: () => go('/dictionary'),
              ),
              _rule(context),
              _item(
                context,
                key: const Key('drawer-translator'),
                section: Section.translator,
                label: (t) => t.translator,
                onTap: () => sheet(showTranslatorSheet),
              ),
            ]),
            _kicker(context, (t) => t.other),
            _card(context, [
              _item(
                context,
                section: Section.settings,
                label: (t) => t.settings,
                onTap: () => go('/settings'),
              ),
              _rule(context),
              _item(
                context,
                section: Section.language,
                label: (t) => t.language,
                onTap: () => sheet(showLanguagePicker),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// A group of rows on a card, like the home page's cards.
  Widget _card(BuildContext context, List<Widget> rows) {
    final brightness = Theme.of(context).brightness;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: brightness.resolve(
          light: AppColors.gridCellLight,
          dark: AppColors.gridCellDark,
        ),
        borderRadius: BorderRadius.circular(Radius.sm),
        border: Border.all(
          color: brightness.resolve(
            light: AppColors.hairlineLight,
            dark: AppColors.hairlineDark,
          ),
          width: 0.5,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }

  /// A thin line between two rows of a card, from the text on.
  Widget _rule(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 64),
    child: Divider(
      height: 0,
      thickness: 0.5,
      color: Theme.of(context).brightness.resolve(
        light: AppColors.hairlineLight,
        dark: AppColors.hairlineDark,
      ),
    ),
  );

  Widget _kicker(BuildContext context, TextPick label) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Spacing.sm,
      Spacing.lg,
      Spacing.sm,
      Spacing.sm,
    ),
    child: DualText(
      label,
      style: kickerStyle(brightness: Theme.of(context).brightness),
      inline: true,
    ),
  );

  /// One row: the section's small icon and its name.
  Widget _item(
    BuildContext context, {
    Key? key,
    required Section section,
    required TextPick label,
    required VoidCallback onTap,
  }) {
    final ink = Theme.of(context).brightness
        .resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm + 4,
          vertical: Spacing.sm,
        ),
        child: Row(
          children: [
            SectionIcon(section, size: 40, compact: true),
            const SizedBox(width: Spacing.sm + 4),
            Expanded(
              child: DualText(
                label,
                style: Theme.of(context).textTheme.titleMedium!
                    .copyWith(color: ink),
                inline: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A game under Games, lined up with the text above; "Coming soon" when
  /// it can't be opened yet (no [onTap]).
  Widget _game(BuildContext context, TextPick label, VoidCallback? onTap) {
    final brightness = Theme.of(context).brightness;
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final coral = SectionIcon.colorOf(Section.games, brightness);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(64, 10, Spacing.md, 10),
        child: Row(
          children: [
            // A small dot in the games' colour.
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: onTap == null ? muted : coral,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: Spacing.sm + 4),
            Expanded(
              child: DualText(
                label,
                // The same font as the rows above, a little lighter.
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: onTap == null ? muted : ink,
                  fontWeight: FontWeight.w400,
                ),
                inline: true,
              ),
            ),
            if (onTap == null)
              DualText(
                (t) => t.comingSoon,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: muted,
                  fontFamily: 'Inter',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
