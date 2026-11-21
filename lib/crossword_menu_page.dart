// ─────────────────────────────────────────────────────────────────────────────
// CROSSWORD MENU — New Game / Continue
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'dual_text.dart';
import 'design_system.dart';
import 'dictionary_search_bar.dart';
import 'crossword_save.dart';
import 'app_text.dart';
import 'puzzle_themes.dart';
import 'theme_picker.dart';

class CrosswordMenuPage extends StatefulWidget {
  const CrosswordMenuPage({super.key});

  @override
  State<CrosswordMenuPage> createState() => _CrosswordMenuPageState();
}

class _CrosswordMenuPageState extends State<CrosswordMenuPage> {
  bool _hasSavedGame = false;
  int? _savedLevel; // level of the saved game, if any
  PuzzleTheme? _savedTheme; // its subject, if one was chosen

  @override
  void initState() {
    super.initState();
    _checkForSavedGame();
  }

  Future<void> _checkForSavedGame() async {
    final savedState = await CrosswordSave.load();
    if (!mounted) return;
    setState(() {
      _hasSavedGame = savedState != null;
      if (savedState != null) {
        _savedLevel = (savedState['currentLevel'] as int?) ?? 1;
        _savedTheme = PuzzleTheme.byId(savedState['theme'] as String?);
      }
    });
  }

  /// New Game: choose a subject first, then start at Level 1.
  Future<void> _startNewGame() async {
    final choice = await showThemePicker(
      context,
      language: AppText.of(context).code,
    );
    if (choice == null || !mounted) return;
    await CrosswordSave.clear();
    if (!mounted) return;
    await Navigator.of(context)
        .pushNamed('/crossword/game', arguments: {'theme': choice.theme});
    if (mounted) _checkForSavedGame();
  }

  Future<void> _continueGame() async {
    final savedState = await CrosswordSave.load();
    if (!mounted || savedState == null) return;
    await Navigator.of(context)
        .pushNamed('/crossword/game', arguments: {'resumeState': savedState});
    if (mounted) _checkForSavedGame();
  }

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
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
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
                  // Back button
                  GestureDetector(
                    key: const Key('crossword-menu-back'),
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
                    child: DictionarySearchBar(
                      fieldKey: Key('crossword-menu-search'),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // Home button
                  const HomeButton(),
                ],
              ),
            ),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    DualText(
                      (t) => t.dailyCrossword,
                      style: kickerStyle(brightness: brightness),
                      inline: true,
                    ),
                    const SizedBox(height: Spacing.xs),
                    DualText(
                      (t) => t.crossword,
                      style: Theme.of(context).textTheme.displayMedium,
                      inline: true,
                    ),
                    const SizedBox(height: Spacing.lg),

                    // ── New Game card ─────────────────────────────────────
                    _menuCard(
                      context: context,
                      title: (t) => t.newGame,
                      subtitle: (t) => t.newGameSubtitle,
                      cardBg: gridCell,
                      borderColor: hairline,
                      onTap: _startNewGame,
                    ),
                    const SizedBox(height: Spacing.md),

                    // ── Continue card ─────────────────────────────────────
                    _menuCard(
                      context: context,
                      title: (t) => t.continueGame,
                      subtitle: (t) => _savedLevel == null
                          ? t.noSavedGame
                          : _savedTheme == null
                          ? t.continueSubtitle(_savedLevel!)
                          : t.continueWithSubject(
                              _savedLevel!,
                              _savedTheme!.name(t),
                            ),
                      cardBg: gridCell,
                      borderColor: hairline,
                      onTap: _hasSavedGame ? _continueGame : () {},
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

  Widget _menuCard({
    required BuildContext context,
    required TextPick title,
    required TextPick subtitle,
    required Color cardBg,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(context).brightness;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(Radius.sm),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        padding: const EdgeInsets.all(Spacing.md),
        constraints: const BoxConstraints(minHeight: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DualText(
              title,
              style: Theme.of(context).textTheme.displaySmall,
              inline: true,
            ),
            const SizedBox(height: Spacing.xs),
            DualText(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: brightness.resolve(
                  light: AppColors.mutedLight,
                  dark: AppColors.mutedDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
