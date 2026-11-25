// ─────────────────────────────────────────────────────────────────────────────
// FIND THE WORDS MENU — New Game / Continue
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'app_text.dart';
import 'design_system.dart';
import 'dictionary_search_bar.dart';
import 'dual_text.dart';
import 'theme_picker.dart';
import 'word_search_game_page.dart';
import 'word_search_save.dart';

class WordSearchMenuPage extends StatefulWidget {
  const WordSearchMenuPage({super.key});

  @override
  State<WordSearchMenuPage> createState() => _WordSearchMenuPageState();
}

class _WordSearchMenuPageState extends State<WordSearchMenuPage> {
  WordSearchProgress? _saved;

  String get _language => AppText.of(context).code;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSaved());
  }

  Future<void> _loadSaved() async {
    final saved = await WordSearchSave.load(language: _language);
    if (mounted) setState(() => _saved = saved);
  }

  /// Open the game; when the player comes back, show the latest save.
  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadSaved();
  }

  /// New Game: choose a subject first, then start at Level 1.
  Future<void> _newGame() async {
    final choice = await showThemePicker(context, language: _language);
    if (choice == null || !mounted) return;
    await WordSearchSave.clear(language: _language);
    if (!mounted) return;
    await _open(WordSearchGamePage(language: _language, theme: choice.theme));
  }

  void _continue() {
    final saved = _saved;
    if (saved == null) return;
    _open(WordSearchGamePage(resume: saved, language: _language));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = brightness.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final card = brightness.resolve(
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
    final saved = _saved;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: Back, dictionary search, Home ────────────────────
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
                    key: const Key('word-search-menu-back'),
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(Radius.sm),
                      ),
                      child: Icon(Icons.arrow_back, size: 20, color: ink),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // Dictionary search, in the middle.
                  const Expanded(
                    child: DictionarySearchBar(
                      fieldKey: Key('word-search-menu-search'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DualText(
                      (t) => t.wordSearchKicker,
                      style: kickerStyle(brightness: brightness),
                      inline: true,
                    ),
                    const SizedBox(height: Spacing.xs),
                    DualText(
                      (t) => t.findTheWords,
                      style: Theme.of(context).textTheme.displayMedium,
                      inline: true,
                    ),
                    const SizedBox(height: Spacing.lg),
                    _menuCard(
                      key: const Key('ws-new-game'),
                      title: (t) => t.newGame,
                      subtitle: (t) => t.newWordSearchSubtitle,
                      card: card,
                      hairline: hairline,
                      brightness: brightness,
                      onTap: _newGame,
                    ),
                    const SizedBox(height: Spacing.md),
                    _menuCard(
                      key: const Key('ws-continue'),
                      title: (t) => t.continueGame,
                      subtitle: (t) => saved == null
                          ? t.noSavedGame
                          : saved.theme == null
                          ? t.continueSubtitle(saved.puzzle.level)
                          : t.continueWithSubject(
                              saved.puzzle.level,
                              saved.theme!.name(t),
                            ),
                      card: card,
                      hairline: hairline,
                      brightness: brightness,
                      onTap: saved == null ? null : _continue,
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
    required Key key,
    required TextPick title,
    required TextPick subtitle,
    required Color card,
    required Color hairline,
    required Brightness brightness,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 100),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(Radius.sm),
          border: Border.all(color: hairline, width: 0.5),
        ),
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
