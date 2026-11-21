// ─────────────────────────────────────────────────────────────────────────────
// LANGUAGE BUTTON — the 🌐 in the top bar (home page, Translator)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'design_system.dart';
import 'settings_page.dart' show showLanguagePicker;

/// Globe button beside Home: opens the language list (the same as Settings >
/// Language). Same size and shape as the Home button, in the card colour.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      key: const Key('language-button'),
      onTap: () => showLanguagePicker(context),
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
          Icons.language,
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
