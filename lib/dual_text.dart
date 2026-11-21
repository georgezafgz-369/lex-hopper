// ─────────────────────────────────────────────────────────────────────────────
// DUAL TEXT — a text in the main language, with its translation in the
// secondary language (Settings > Language) on a small grey line underneath
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'design_system.dart';

/// Picks one text from [AppText], e.g. `(t) => t.crossword`, so it can be
/// read in both languages.
typedef TextPick = String Function(AppText t);

/// The app's text in the secondary language, or null when there is no
/// secondary language (or it is the same as the main one).
AppText? secondaryText(BuildContext context) {
  final code = AppSettings.instance.secondaryLanguage;
  if (code == null || code == AppText.of(context).code) return null;
  return AppText.forCode(code);
}

/// The colour of secondary-language translations (on plain backgrounds):
/// orange, so they stand apart from the main text.
Color translationColor(BuildContext context) => Theme.of(context).brightness
    .resolve(
      light: AppColors.translationLight,
      dark: AppColors.translationDark,
    );

/// "Search dictionary..." or, with a secondary language,
/// "Search dictionary... (Αναζήτηση στο λεξικό...)", for places that hold a
/// single line of text (hints, buttons).
String dualString(BuildContext context, TextPick pick) {
  final main = pick(AppText.of(context));
  final second = secondaryText(context);
  return second == null ? main : '$main (${pick(second)})';
}

/// Shows [pick] in the main language with [style]; when a secondary
/// language is set, its translation follows, smaller and in orange.
/// Rebuilds by itself when the secondary language changes.
class DualText extends StatelessWidget {
  final TextPick pick;
  final TextStyle? style;

  /// Style of the translation; defaults to [style], 80% of its size, in
  /// the translation colour (orange).
  final TextStyle? secondaryStyle;
  final TextAlign? textAlign;
  final CrossAxisAlignment crossAxisAlignment;

  /// True: the translation follows right after the main text on the same
  /// line (titles, section labels); false: on its own line underneath.
  final bool inline;

  const DualText(
    this.pick, {
    super.key,
    this.style,
    this.secondaryStyle,
    this.textAlign,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.inline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final main = Text(
          pick(AppText.of(context)),
          style: style,
          textAlign: textAlign,
        );
        final second = secondaryText(context);
        if (second == null) return main;
        final base = style ?? DefaultTextStyle.of(context).style;
        final secondStyle =
            secondaryStyle ??
            base.copyWith(
              fontSize: (base.fontSize ?? 14) * 0.8,
              color: translationColor(context),
              fontWeight: FontWeight.w400,
            );
        if (inline) {
          // One text, so it wraps naturally if the line is too short.
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: pick(AppText.of(context)), style: style),
                TextSpan(text: '  ${pick(second)}', style: secondStyle),
              ],
            ),
            textAlign: textAlign,
          );
        }
        return Column(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: MainAxisSize.min,
          children: [
            main,
            const SizedBox(height: 2),
            Text(pick(second), textAlign: textAlign, style: secondStyle),
          ],
        );
      },
    );
  }
}
