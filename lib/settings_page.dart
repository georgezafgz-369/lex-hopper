// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PAGE — Language and Dark mode
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'bottom_menu.dart';
import 'app_text.dart';
import 'dual_text.dart';
import 'design_system.dart';
import 'eurollm_translator.dart';
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
          body: BottomMenu(
            current: Section.settings,
            child: SafeArea(
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
                        BottomMenu.space, // clear of the bottom menu
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
                          const SizedBox(height: Spacing.md),

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
                          const SizedBox(height: Spacing.md),
                          _FontSizeCard(settings: settings),
                          const SizedBox(height: Spacing.md),
                          _AiTranslatorCard(
                            settings: settings,
                            model: EuroLlmTranslator.instance,
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
                          const SizedBox(height: Spacing.md),

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
                                children: [Text(t.translatorCredit)],
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

/// AI translator: a switch that downloads EuroLLM (after asking) and then
/// makes the Translator use it. Shows the download's progress; turning it
/// off asks whether to keep or delete the 1 GB model.
class _AiTranslatorCard extends StatefulWidget {
  final AppSettings settings;
  final EuroLlmTranslator model;

  const _AiTranslatorCard({required this.settings, required this.model});

  @override
  State<_AiTranslatorCard> createState() => _AiTranslatorCardState();
}

class _AiTranslatorCardState extends State<_AiTranslatorCard> {
  @override
  void initState() {
    super.initState();
    widget.model.refresh();
  }

  Future<void> _turnOn() async {
    final model = widget.model;
    if (model.state == ModelState.ready) {
      await widget.settings.setAiTranslator(true);
      return;
    }
    final mb = EuroLlmTranslator.sizeMb;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('ai-download-dialog'),
        title: DualText((t) => t.aiDownloadTitle),
        content: DualText((t) => t.aiDownloadBody(mb)),
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
    await widget.settings.setAiTranslator(true);
    await model.download();
  }

  Future<void> _turnOff() async {
    final model = widget.model;
    if (model.state == ModelState.downloading) model.cancelDownload();
    if (model.state != ModelState.ready) {
      await widget.settings.setAiTranslator(false);
      return;
    }
    final mb = EuroLlmTranslator.sizeMb;
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('ai-off-dialog'),
        title: DualText((t) => t.aiTurnOffTitle),
        content: DualText((t) => t.aiTurnOffBody(mb)),
        actions: [
          TextButton(
            key: const Key('ai-delete-model'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppText.of(context).deleteModel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppText.of(context).keepModel),
          ),
        ],
      ),
    );
    if (delete == null) return; // dismissed: stays on
    await widget.settings.setAiTranslator(false);
    if (delete) await model.deleteModel();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final clay = Theme.of(context).brightness
        .resolve(light: AppColors.clayLight, dark: AppColors.clayDark);
    return ListenableBuilder(
      listenable: model.changes,
      builder: (context, _) {
        final on = widget.settings.aiTranslator;
        final state = model.state;
        final tooSmall = state == ModelState.tooLittleMemory;
        final TextPick subtitle = switch ((on, state)) {
          (_, ModelState.tooLittleMemory) => (t) => t.aiTranslatorNeedsMemory,
          (_, ModelState.downloading) => (t) => t.aiTranslatorDownloading(
            model.progress == null ? null : (model.progress! * 100).floor(),
          ),
          (true, ModelState.failed) => (t) => t.aiTranslatorFailed,
          (true, ModelState.checking) => (t) => t.aiTranslatorChecking,
          (true, ModelState.ready) => (t) => t.aiTranslatorOn,
          _ => (t) => t.aiTranslatorOff,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsCard(
              key: const Key('settings-ai-translator'),
              icon: Section.aiTranslator,
              title: (t) => t.aiTranslator,
              subtitle: subtitle,
              trailing: Switch(
                key: const Key('ai-translator-switch'),
                value: on && !tooSmall,
                activeThumbColor: clay,
                onChanged: tooSmall ? null : (v) => v ? _turnOn() : _turnOff(),
              ),
              onTap: () {
                if (tooSmall) return;
                // A stopped download: tapping the card tries again.
                if (on && state == ModelState.failed) {
                  model.download();
                } else {
                  on ? _turnOff() : _turnOn();
                }
              },
            ),
            if (state == ModelState.downloading)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: LinearProgressIndicator(
                  key: const Key('ai-download-progress'),
                  value: model.progress,
                  color: clay,
                  backgroundColor: Theme.of(context).brightness.resolve(
                    light: AppColors.hairlineLight,
                    dark: AppColors.hairlineDark,
                  ),
                ),
              ),
          ],
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
  final Widget trailing;
  final VoidCallback onTap;

  const _SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
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
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            SectionIcon(icon),
            const SizedBox(width: Spacing.md),
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
            const SizedBox(width: Spacing.sm),
            trailing,
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
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SectionIcon(Section.fontSize),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: DualText(
                  (t) => t.fontSize,
                  style: Theme.of(context).textTheme.displaySmall,
                  inline: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
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
    return ListenableBuilder(
      listenable: settings,
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
                      if (!language.available)
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

  /// The languages in list order: main, secondary, then the others.
  List<AppLanguage> _ordered(BuildContext context, AppSettings settings) {
    final main = Localizations.localeOf(context).languageCode;
    final second = settings.secondaryLanguage;
    int rank(AppLanguage l) => l.code == main
        ? 0
        : l.code == second
        ? 1
        : 2;
    final list = [...appLanguages];
    // Stable: keeps the original order among the rest.
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final r = rank(a.value).compareTo(rank(b.value));
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    return [for (final e in indexed) e.value];
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
    }
  }
}
