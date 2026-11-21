// ─────────────────────────────────────────────────────────────────────────────
// MENU CARD — a full-width tappable card with a title and a description,
// used on the home page and the Games page
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'dual_text.dart';
import 'design_system.dart';

class MenuCard extends StatelessWidget {
  final TextPick title;
  final TextPick subtitle;
  final VoidCallback onTap;

  /// Shows a "Coming soon" tag beside the title.
  final bool comingSoon;

  /// Shows a chevron on the right, for cards that open a list of more items.
  final bool chevron;

  const MenuCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comingSoon = false,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title, with a "Coming soon" tag for games not playable yet.
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DualText(
              title,
              style: Theme.of(context).textTheme.displaySmall!,
              inline: true,
            ),
            if (comingSoon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: muted, width: 0.8),
                ),
                child: DualText(
                  (t) => t.comingSoon,
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: muted,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        DualText(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: muted),
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Full width, so every card is the same size whatever its text.
        width: double.infinity,
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
        padding: const EdgeInsets.all(Spacing.md),
        child: chevron
            ? Row(
                children: [
                  Expanded(child: content),
                  const SizedBox(width: Spacing.sm),
                  Icon(Icons.chevron_right, color: muted),
                ],
              )
            : content,
      ),
    );
  }
}
