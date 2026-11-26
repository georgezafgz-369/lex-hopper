// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PAGE — Language and Dark mode
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'dual_text.dart';
import 'design_system.dart';
import 'dictionary_search_bar.dart';
import 'ai_model.dart';
import 'language_packs.dart';
import 'section_icon.dart';
import 'word_sheet.dart' show showDraggableSheet;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final codeInUse = Localizations.localeOf(context).languageCode;
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
        final clay = brightness.resolve(
          light: AppColors.clayLight,
          dark: AppColors.clayDark,
        );
        // Before the switch is first used, it shows what the phone uses.
        final isDark = settings.darkMode ?? brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: paper,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.md,
                    Spacing.sm,
                    Spacing.md,
                    Spacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
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
                      const Expanded(child: DictionarySearchToggle()),
                    ],
                  ),
                ),

                // ── Content ───────────────────────────────────────────────
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
                        // The page's title, big and bold, like Games.
                        const SizedBox(height: Spacing.sm),
                        DualText(
                          (t) => AppText.upper(t.settings),
                          style: Theme.of(context).textTheme.displayLarge,
                          inline: true,
                        ),
                        const SizedBox(height: Spacing.lg),

                        _SettingsCard(
                          key: const Key('settings-language'),
                          icon: Section.language,
                          title: (t) => t.language,
                          subtitle: (t) => settings.secondaryLanguage == null
                              ? t.languageName(
                                  settings.languageInUse(codeInUse).code,
                                )
                              // Each line names the languages in its own
                              // language: "English · secondary: Greek" /
                              // "Αγγλικά · δευτερεύουσα: Ελληνικά".
                              : t.withSecondary(
                                  t.languageName(
                                    settings.languageInUse(codeInUse).code,
                                  ),
                                  t.languageName(settings.secondaryLanguage!),
                                ),
                          trailing: Icon(Icons.chevron_right, color: ink),
                          onTap: () => showLanguagePicker(context),
                        ),
                        const SizedBox(height: Spacing.sm),

                        // The picked model (a new card when it changes).
                        _AiTranslatorCard(
                          key: ValueKey(AiModel.instance.id),
                          settings: settings,
                          model: AiModel.instance,
                        ),
                        // ── Separator: the text and reading settings ───
                        const SizedBox(height: Spacing.lg),
                        Divider(
                          color: brightness.resolve(
                            light: AppColors.hairlineLight,
                            dark: AppColors.hairlineDark,
                          ),
                          height: 0,
                        ),
                        const SizedBox(height: Spacing.lg),
                        _SettingsCard(
                          key: const Key('settings-dark-mode'),
                          icon: Section.darkMode,
                          title: (t) => t.darkMode,
                          subtitle: (t) => isDark ? t.on : t.off,
                          trailing: Switch(
                            value: isDark,
                            activeThumbColor: clay,
                            onChanged: settings.setDarkMode,
                          ),
                          onTap: () => settings.setDarkMode(!isDark),
                        ),
                        const SizedBox(height: Spacing.sm),
                        _FontSizeCard(settings: settings),
                        const SizedBox(height: Spacing.sm),
                        _SettingsCard(
                          key: const Key('settings-word-look-up'),
                          icon: Section.wordLookUp,
                          title: (t) => t.wordLookUp,
                          subtitle: (t) =>
                              settings.wordLookUp ? t.wordLookUpOn : t.off,
                          trailing: Switch(
                            value: settings.wordLookUp,
                            activeThumbColor: clay,
                            onChanged: settings.setWordLookUp,
                          ),
                          onTap: () =>
                              settings.setWordLookUp(!settings.wordLookUp),
                        ),

                        // ── Separator ───────────────────────────────────
                        const SizedBox(height: Spacing.lg),
                        Divider(
                          color: brightness.resolve(
                            light: AppColors.hairlineLight,
                            dark: AppColors.hairlineDark,
                          ),
                          height: 0,
                        ),
                        const SizedBox(height: Spacing.lg),

                        _SettingsCard(
                          key: const Key('settings-feedback'),
                          icon: Section.feedback,
                          title: (t) => t.feedback,
                          subtitle: (t) => t.feedbackSubtitle,
                          trailing: Icon(Icons.mail_outline, color: ink),
                          onTap: () => _sendFeedback(context),
                        ),
                        const SizedBox(height: Spacing.sm),

                        _SettingsCard(
                          key: const Key('settings-about'),
                          icon: Section.about,
                          title: (t) => t.aboutTheApp,
                          subtitle: (t) => t.aboutTheAppSubtitle,
                          trailing: Icon(Icons.chevron_right, color: ink),
                          // The app's credits (the translator's licence
                          // asks for one) and the licences of what it uses.
                          onTap: () {
                            final t = AppText.of(context);
                            showAboutDialog(
                              context: context,
                              applicationName: 'Lex Hopper',
                              children: [
                                Text(t.translatorCredit),
                                const SizedBox(height: Spacing.sm),
                                Text(t.packCredits),
                              ],
                            );
                          },
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
      },
    );
  }

  /// Opens the email app with a new message to [feedbackEmail]. If the
  /// phone has no email app, shows the address instead.
  Future<void> _sendFeedback(BuildContext context) async {
    final t = AppText.of(context);
    final subject = Uri.encodeComponent(t.feedbackSubject);
    final uri = Uri.parse('mailto:$feedbackEmail?subject=$subject');
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(
          content: DualText(
            (t) => t.noEmailApp(feedbackEmail),
            style: const TextStyle(color: Colors.white),
            secondaryStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }
}

/// Pop-up list of languages (Settings > Language, and the globe button on
/// the home page): tap one to set it as the main or secondary language.
/// Only the available ones can be picked.
void showLanguagePicker(BuildContext context) {
  showDraggableSheet(
    context,
    builder: (scrollController) => _LanguageList(scrollController),
  );
}

/// AI model: one card holding the four models. Each can be downloaded
/// (after asking) or deleted from its own tile; tapping a model that's on
/// the phone makes it the active one (the Translator and Chat with AI use
/// it), tapping the active one turns the AI off. Only one is active.
class _AiTranslatorCard extends StatefulWidget {
  final AppSettings settings;
  final AiModel model;

  const _AiTranslatorCard({
    super.key,
    required this.settings,
    required this.model,
  });

  @override
  State<_AiTranslatorCard> createState() => _AiTranslatorCardState();
}

class _AiTranslatorCardState extends State<_AiTranslatorCard> {
  AppSettings get _settings => widget.settings;

  @override
  void initState() {
    super.initState();
    // Every model: which ones are on the phone already.
    for (final m in AiModel.all) {
      m.refresh();
    }
  }

  /// Makes [m] the model in use (on the phone already).
  Future<void> _activate(AiModel m) async {
    await _settings.setAiModel(m.id);
    await _settings.setAiTranslator(true);
  }

  /// A tile tapped: on the phone, it becomes active (or, active already,
  /// the AI turns off); not yet, it offers the download.
  Future<void> _tap(AiModel m) async {
    switch (m.state) {
      case ModelState.ready:
        final active = _settings.aiTranslator && m.id == widget.model.id;
        active ? await _settings.setAiTranslator(false) : await _activate(m);
      case ModelState.notDownloaded || ModelState.failed:
        await _download(m);
      default:
    }
  }

  /// Asks, then downloads [m]; once it's here it becomes the active one.
  Future<void> _download(AiModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('ai-download-dialog'),
        title: DualText((t) => t.aiDownloadTitle(m.name)),
        content: DualText((t) => t.aiDownloadBody(m.name, m.sizeMb)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppText.of(context).cancel),
          ),
          FilledButton(
            key: const Key('ai-download-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppText.of(context).download),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await m.download();
    if (m.state == ModelState.ready) await _activate(m);
  }

  /// Asks, then deletes [m] from the phone (the AI turns off if it was
  /// the one in use).
  Future<void> _delete(AiModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('ai-delete-dialog'),
        title: DualText((t) => t.aiDeleteTitle(m.name)),
        content: DualText((t) => t.aiDeleteBody(m.sizeMb)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppText.of(context).cancel),
          ),
          FilledButton(
            key: const Key('ai-delete-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppText.of(context).deleteModel),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (m.id == widget.model.id) await _settings.setAiTranslator(false);
    await m.deleteModel();
    await m.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return ListenableBuilder(
      listenable: Listenable.merge([for (final m in AiModel.all) m.changes]),
      builder: (context, _) {
        final on = _settings.aiTranslator && model.state == ModelState.ready;
        final downloading = AiModel.all
            .where((m) => m.state == ModelState.downloading)
            .firstOrNull;
        final TextPick subtitle = downloading != null
            ? (t) => t.aiTranslatorDownloading(
                downloading.name,
                downloading.progress == null
                    ? null
                    : (downloading.progress! * 100).floor(),
              )
            : on
            ? (t) => t.aiTranslatorOn(model.name)
            : (t) => t.aiTranslatorOff;
        return _SettingsCard(
          key: const Key('settings-ai-translator'),
          icon: Section.aiTranslator,
          title: (t) => t.aiTranslator,
          subtitle: subtitle,
          // The models, two to a row.
          below: Column(
            children: [
              for (var r = 0; r < AiModel.all.length; r += 2) ...[
                if (r > 0) const SizedBox(height: Spacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = r; i < r + 2; i++) ...[
                      if (i > r) const SizedBox(width: Spacing.sm),
                      Expanded(
                        child: i >= AiModel.all.length
                            ? const SizedBox.shrink()
                            : _ModelChoice(
                                key: Key('ai-model-${AiModel.all[i].id}'),
                                model: AiModel.all[i],
                                active: on && AiModel.all[i].id == model.id,
                                onTap: () => _tap(AiModel.all[i]),
                                onDownload: () => _download(AiModel.all[i]),
                                onDelete: () => _delete(AiModel.all[i]),
                              ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// A settings card in the home page style: small red label, title, current
/// value, and a control (switch or arrow) on the right.
class _SettingsCard extends StatelessWidget {
  /// The doodle on the left, like the home page's cards.
  final Section icon;
  final TextPick title;
  final TextPick subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// More inside the card, under its title (the AI models).
  final Widget? below;

  const _SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md - 4,
          vertical: Spacing.sm + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SectionIcon(icon, size: 46),
                const SizedBox(width: Spacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                if (trailing != null) ...[
                  const SizedBox(width: Spacing.sm),
                  trailing!,
                ],
              ],
            ),
            if (below != null) ...[const SizedBox(height: Spacing.sm), below!],
          ],
        ),
      ),
    );
  }
}

/// "Font size" card with Small · Medium · Large buttons; the active one is
/// filled clay. The change applies to the whole app at once.
class _FontSizeCard extends StatelessWidget {
  final AppSettings settings;
  const _FontSizeCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final clay = brightness.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final gridCell = brightness.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    return Container(
      key: const Key('settings-font-size'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: gridCell,
        borderRadius: BorderRadius.circular(Radius.sm),
        border: Border.all(color: hairline, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md - 4,
        vertical: Spacing.sm + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionIcon(Section.fontSize, size: 46),
              const SizedBox(width: Spacing.sm + 4),
              Expanded(
                child: DualText(
                  (t) => t.fontSize,
                  style: Theme.of(context).textTheme.displaySmall,
                  inline: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              for (final (i, option) in FontSizeOption.values.indexed) ...[
                if (i > 0) const SizedBox(width: Spacing.sm),
                Expanded(
                  child: GestureDetector(
                    key: Key('font-size-${option.name}'),
                    onTap: () => settings.setFontSize(option),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: settings.fontSize == option
                            ? clay
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(Radius.sm),
                        border: Border.all(
                          color: settings.fontSize == option ? clay : hairline,
                        ),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: DualText(
                            (t) => switch (option) {
                              FontSizeOption.small => t.small,
                              FontSizeOption.medium => t.medium,
                              FontSizeOption.large => t.large,
                            },
                            crossAxisAlignment: CrossAxisAlignment.center,
                            secondaryStyle: TextStyle(
                              fontSize: 11 * option.scale,
                              fontFamily: 'Inter',
                              color: settings.fontSize == option
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : translationColor(context),
                            ),
                            style: TextStyle(
                              // Each button previews its own size.
                              fontSize: 15 * option.scale,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              color: settings.fontSize == option
                                  ? Colors.white
                                  : ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageList extends StatelessWidget {
  final ScrollController scrollController;
  const _LanguageList(this.scrollController);

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final packs = LanguagePacks.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, packs]),
      builder: (context, _) {
        final brightness = Theme.of(context).brightness;
        final ink = brightness.resolve(
          light: AppColors.inkLight,
          dark: AppColors.inkDark,
        );
        final muted = brightness.resolve(
          light: AppColors.mutedLight,
          dark: AppColors.mutedDark,
        );
        final clay = brightness.resolve(
          light: AppColors.clayLight,
          dark: AppColors.clayDark,
        );
        final hairline = brightness.resolve(
          light: AppColors.hairlineLight,
          dark: AppColors.hairlineDark,
        );
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.xl,
          ),
          children: [
            DualText(
              (t) => t.language,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: ink),
              inline: true,
            ),
            const SizedBox(height: Spacing.md),
            // Main language first, then the secondary one, then the rest.
            for (final language in _ordered(context, settings)) ...[
              InkWell(
                key: Key('language-${language.code}'),
                onTap: language.available
                    ? () => _chooseRole(context, settings, language)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                  child: Row(
                    children: [
                      // The country's flag, faded while not available.
                      if (FlagIcon.has(language.code)) ...[
                        Opacity(
                          opacity: language.available ? 1 : 0.45,
                          child: FlagIcon(language.code),
                        ),
                        const SizedBox(width: Spacing.md),
                      ],
                      Expanded(
                        // The name in the main language, with the
                        // secondary language's name next to it.
                        child: DualText(
                          (t) => t.languageName(language.code),
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'Inter',
                            color: language.available ? ink : muted,
                          ),
                          inline: true,
                        ),
                      ),
                      if (language.isPack && !language.available)
                        _PackControl(language.code)
                      else if (!language.available)
                        DualText(
                          (t) => t.comingSoon,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Inter',
                            color: muted,
                          ),
                        )
                      else if (Localizations.localeOf(context).languageCode ==
                          language.code) ...[
                        _roleTag((t) => t.mainLanguage, clay),
                      ] else if (settings.secondaryLanguage == language.code)
                        _roleTag((t) => t.secondaryLanguage, muted),
                    ],
                  ),
                ),
              ),
              Divider(color: hairline, height: 1),
            ],
          ],
        );
      },
    );
  }

  /// The languages in list order: main, secondary, then the ones on the
  /// phone, the ones to download, and the ones coming soon — each group in
  /// alphabetical order of its name in the app's language.
  List<AppLanguage> _ordered(BuildContext context, AppSettings settings) {
    final main = Localizations.localeOf(context).languageCode;
    final second = settings.secondaryLanguage;
    final t = AppText.of(context);
    int group(AppLanguage l) => l.code == main
        ? 0
        : l.code == second
        ? 1
        : l.available
        ? 2
        : l.isPack
        ? 3
        : 4;
    return [...appLanguages]..sort((a, b) {
      final g = group(a).compareTo(group(b));
      return g != 0
          ? g
          : t.languageName(a.code).compareTo(t.languageName(b.code));
    });
  }

  /// Small label next to a language: "Main" / "Secondary".
  Widget _roleTag(TextPick label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(Radius.sm),
      border: Border.all(color: color),
    ),
    child: DualText(
      label,
      inline: true,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
        color: color,
      ),
    ),
  );

  /// Tapping a language asks: set it as the main or the secondary language
  /// (or remove it as secondary, if it already is).
  Future<void> _chooseRole(
    BuildContext context,
    AppSettings settings,
    AppLanguage language,
  ) async {
    final main = Localizations.localeOf(context).languageCode;
    final isMain = language.code == main;
    final isSecondary = settings.secondaryLanguage == language.code;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: DualText(
                (t) => t.languageName(language.code),
                style: Theme.of(sheetContext).textTheme.titleLarge,
                inline: true,
              ),
            ),
            if (!isMain)
              ListTile(
                key: const Key('set-main'),
                leading: const Icon(Icons.star_outline),
                title: DualText((t) => t.setAsMain),
                onTap: () => Navigator.of(sheetContext).pop('main'),
              ),
            if (!isMain && !isSecondary)
              ListTile(
                key: const Key('set-secondary'),
                leading: const Icon(Icons.looks_two_outlined),
                title: DualText((t) => t.setAsSecondary),
                onTap: () => Navigator.of(sheetContext).pop('secondary'),
              ),
            if (isSecondary)
              ListTile(
                key: const Key('remove-secondary'),
                leading: const Icon(Icons.close),
                title: DualText((t) => t.removeSecondary),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
            if (isMain)
              ListTile(
                leading: const Icon(Icons.check),
                title: DualText((t) => t.mainLanguage),
                enabled: false,
              ),
            // A downloaded language can be taken off the phone (not while
            // it's the main language).
            if (language.isPack && !isMain)
              ListTile(
                key: const Key('remove-pack'),
                leading: const Icon(Icons.delete_outline),
                title: DualText(
                  (t) => t.removeLanguagePack(
                    LanguagePacks.instance.sizeMb(language.code),
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            const SizedBox(height: Spacing.sm),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'main':
        await settings.setLanguage(language.code);
      case 'secondary':
        await settings.setSecondaryLanguage(language.code);
      case 'remove':
        await settings.setSecondaryLanguage(null);
      case 'delete':
        if (isSecondary) await settings.setSecondaryLanguage(null);
        await LanguagePacks.instance.delete(language.code);
    }
  }
}

/// Beside a language you can download: "Download · 600 MB" (asking first),
/// then a progress bar with ✕ to stop, or "Try again" after a failure.
class _PackControl extends StatelessWidget {
  final String code;
  const _PackControl(this.code);

  Future<void> _ask(BuildContext context) async {
    final packs = LanguagePacks.instance;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('pack-download-dialog'),
        title: DualText((t) => t.downloadLanguageTitle(t.languageName(code))),
        content: DualText((t) => t.downloadLanguageBody(packs.sizeMb(code))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: DualText((t) => t.cancel, inline: true),
          ),
          TextButton(
            key: const Key('pack-download-yes'),
            onPressed: () => Navigator.of(c).pop(true),
            child: DualText((t) => t.download, inline: true),
          ),
        ],
      ),
    );
    if (yes == true) packs.download(code).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final packs = LanguagePacks.instance;
    final b = Theme.of(context).brightness;
    final clay = b.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final muted = b.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final hairline = b.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      fontFamily: 'Inter',
      color: clay,
    );
    return switch (packs.state(code)) {
      PackState.downloading => Row(
        key: Key('pack-progress-$code'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: LinearProgressIndicator(
              value: packs.progress(code),
              color: clay,
              backgroundColor: hairline,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(packs.progress(code) * 100).floor()}%',
            style: style.copyWith(color: muted),
          ),
          IconButton(
            key: Key('pack-cancel-$code'),
            icon: Icon(Icons.close, size: 18, color: muted),
            onPressed: () => packs.cancel(code),
          ),
        ],
      ),
      final s => OutlinedButton.icon(
        key: Key('pack-download-$code'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: clay),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
        ),
        icon: Icon(
          s == PackState.failed ? Icons.refresh : Icons.download_rounded,
          size: 18,
          color: clay,
        ),
        // The main language only: both would squeeze the language's name
        // until it breaks mid-word.
        label: Text(
          s == PackState.failed
              ? AppText.of(context).tryAgain
              : '${AppText.of(context).download} · ${packs.sizeMb(code)} MB',
          style: style,
        ),
        onPressed: () => s == PackState.failed
            ? packs.download(code).ignore()
            : _ask(context),
      ),
    };
  }
}

/// One AI model to pick: its name and size, outlined when picked.
/// One AI model: its name, then whether it's on the phone (or its size, or
/// the download's progress), and the one in use marked Active. A button
/// in its corner downloads it, stops the download, or deletes it.
class _ModelChoice extends StatelessWidget {
  final AiModel model;

  /// The model in use.
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _ModelChoice({
    super.key,
    required this.model,
    required this.active,
    required this.onTap,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final b = Theme.of(context).brightness;
    final clay = b.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final ink = b.resolve(light: AppColors.inkLight, dark: AppColors.inkDark);
    final muted = b.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final hairline = b.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final paper = b.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final fern = b.resolve(
      light: AppColors.fernLight,
      dark: AppColors.fernDark,
    );
    final state = model.state;
    final tooSmall = state == ModelState.tooLittleMemory;

    Widget corner(Key key, IconData icon, Color color, VoidCallback f) =>
        InkResponse(
          key: key,
          onTap: f,
          radius: 18,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 20, color: color),
          ),
        );

    final status = switch (state) {
      ModelState.ready => Row(
        key: Key('ai-model-on-phone-${model.id}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 14, color: fern),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              t.aiOnPhone,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fern,
              ),
            ),
          ),
        ],
      ),
      ModelState.downloading => Text(
        '${((model.progress ?? 0) * 100).floor()}%',
        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: clay),
      ),
      ModelState.tooLittleMemory => Text(
        t.aiTranslatorNeedsMemory((model.minMemoryKb / (1024 * 1024)).ceil()),
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: muted),
      ),
      _ => Text(
        t.aiModelSize(model.sizeMb),
        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: muted),
      ),
    };

    return Opacity(
      opacity: tooSmall ? 0.5 : 1,
      child: GestureDetector(
        onTap: tooSmall ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(
            Spacing.xs,
            Spacing.sm,
            Spacing.xs,
            Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(Radius.sm),
            border: Border.all(
              color: active ? clay : hairline,
              width: active ? 2.5 : 0.5,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20), // the corner button's row
                  Text(
                    model.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: active ? clay : ink,
                    ),
                  ),
                  Center(child: status),
                  if (state == ModelState.downloading)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinearProgressIndicator(
                        key: Key('ai-download-progress-${model.id}'),
                        value: model.progress,
                        color: clay,
                        backgroundColor: hairline,
                      ),
                    ),
                  if (active)
                    Center(
                      child: Container(
                        key: Key('ai-model-active-${model.id}'),
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: clay,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          t.aiActive,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Download / stop / delete, at the top.
              Positioned(
                top: -4,
                right: 0,
                child: switch (state) {
                  ModelState.ready => corner(
                    Key('ai-delete-${model.id}'),
                    Icons.delete_outline_rounded,
                    muted,
                    onDelete,
                  ),
                  ModelState.downloading => corner(
                    Key('ai-cancel-${model.id}'),
                    Icons.close_rounded,
                    muted,
                    model.cancelDownload,
                  ),
                  ModelState.tooLittleMemory ||
                  ModelState.checking => const SizedBox.shrink(),
                  _ => corner(
                    Key('ai-download-${model.id}'),
                    Icons.download_rounded,
                    clay,
                    onDownload,
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
