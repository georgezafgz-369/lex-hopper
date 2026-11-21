// ─────────────────────────────────────────────────────────────────────────────
// APP DRAWER — the side menu opened by the ☰ button on the home page: Home,
// the games, Dictionary, Settings and Language
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'dual_text.dart';
import 'design_system.dart';
import 'settings_page.dart' show showLanguagePicker;

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
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );

    /// Closes the drawer, then opens [route] (Home just closes it).
    void go(String route) {
      final navigator = Navigator.of(context);
      navigator.pop();
      if (route != '/') navigator.pushNamed(route);
    }

    return Drawer(
      key: const Key('app-drawer'),
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: Spacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.sm,
                Spacing.lg,
                Spacing.lg,
              ),
              child: Text(
                'Lex Hopper',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            _item(
              context,
              icon: Icons.home_outlined,
              label: (t) => t.home,
              onTap: () => go('/'),
            ),
            _divider(hairline),

            _kicker(context, (t) => t.games),
            _item(
              context,
              label: (t) => t.crossword,
              onTap: () => go('/crossword'),
            ),
            _item(
              context,
              label: (t) => t.findTheWords,
              onTap: () => go('/word-search'),
            ),
            _item(context, label: (t) => t.riddles, comingSoon: true),
            _divider(hairline),

            _item(
              context,
              icon: Icons.menu_book_outlined,
              label: (t) => t.dictionary,
              onTap: () => go('/dictionary'),
            ),
            _item(
              context,
              icon: Icons.settings_outlined,
              label: (t) => t.settings,
              onTap: () => go('/settings'),
            ),
            _item(
              context,
              icon: Icons.language,
              label: (t) => t.language,
              onTap: () {
                // The drawer closes, so the picker opens from the
                // navigator, which stays.
                final navigator = Navigator.of(context);
                navigator.pop();
                showLanguagePicker(navigator.context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(Color hairline) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: Spacing.lg,
      vertical: Spacing.sm,
    ),
    child: Divider(color: hairline, height: 0, thickness: 0.5),
  );

  Widget _kicker(BuildContext context, TextPick label) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Spacing.lg,
      Spacing.sm,
      Spacing.lg,
      Spacing.xs,
    ),
    child: DualText(
      label,
      style: kickerStyle(brightness: Theme.of(context).brightness),
      inline: true,
    ),
  );

  /// One row: an optional icon, the label, and a "Coming soon" note for
  /// items that can't be opened yet (no [onTap]).
  Widget _item(
    BuildContext context, {
    IconData? icon,
    required TextPick label,
    VoidCallback? onTap,
    bool comingSoon = false,
  }) {
    final brightness = Theme.of(context).brightness;
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final style = Theme.of(context).textTheme.titleMedium!
        .copyWith(color: comingSoon ? muted : ink);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: 12,
        ),
        child: Row(
          children: [
            // Items without an icon (the games) line up under the text.
            SizedBox(
              width: 32,
              child: icon == null ? null : Icon(icon, size: 20, color: ink),
            ),
            Expanded(child: DualText(label, style: style, inline: true)),
            if (comingSoon)
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
