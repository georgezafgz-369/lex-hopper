// ─────────────────────────────────────────────────────────────────────────────
// TRANSLATOR PAGE — English ↔ Greek, translated on the phone.
//
//   [←] [🔍 Search dictionary…] [🌐] [⌂]
//   English                        ✕
//   Good day                          ← typed, large
//   🔊                              ⧉
//              ──────────
//   Greek
//   Καλή μέρα                         ← translation, large
//   🔊                              ⧉
//   ...
//   [ English ]   ⇄   [ Greek ]       ← language bar, always at the bottom
//
// Empty, the top shows a big "Translate text" and a Paste button.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_text.dart';
import 'app_settings.dart';
import 'design_system.dart';
import 'dictionary_service.dart';
import 'dictionary_search_bar.dart';
import 'language_button.dart';
import 'dual_text.dart';
import 'ai_model.dart';
import 'opus_mt_service.dart';
import 'section_icon.dart';
import 'speech.dart';
import 'saved_translations.dart';
import 'translator_service.dart';

/// A word or phrase as the lexicon knows it: its main translation (null
/// when the lexicon doesn't have it) and its meanings in the other
/// language.
typedef LexiconAnswer = ({String? main, List<WordTranslation> meanings});

/// Looks [text] up in the lexicon of [language] ("en"/"el").
typedef WordLookup = Future<LexiconAnswer> Function(
  String text,
  String language,
);

/// The Translator, sliding up from the bottom over the current page. It
/// closes with its X or by dragging it down.
Future<void> showTranslatorSheet(BuildContext context) {
  final paper = Theme.of(context).brightness
      .resolve(light: AppColors.paperLight, dark: AppColors.paperDark);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: paper,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: ui.Radius.circular(Radius.lg)),
    ),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.94,
      child: const TranslatorPage(asSheet: true),
    ),
  );
}

/// What the app's own data says [text] (in [language]) is in the other
/// language, before any translator is asked: the phrasebook's checked
/// sentence, else the dictionary's main translation, plus the dictionary's
/// meanings for a word.
Future<LexiconAnswer> lookUpInLexicon(String text, String language) async {
  final lexicon = DictionaryService.forLanguage(language);
  return (
    main:
        await lexicon.phrasebookTranslation(text) ??
        await lexicon.mainTranslation(text),
    meanings: await lexicon.translationsOf(text),
  );
}

class TranslatorPage extends StatefulWidget {
  /// What translates; unless a test gives one, the offline translator
  /// (OPUS-MT) when downloaded, else the AI model (EuroLLM) when it's on.
  /// With neither, the page says where to get one.
  final Translator? translator;

  /// Looks a word up in the dictionary of [language] ("en"/"el"); the app's
  /// dictionary unless a test gives another.
  final WordLookup lookup;

  /// Texts translated before on this phone; the phone's own memory unless a
  /// test gives another.
  final SavedTranslations? saved;

  /// Shown in a bottom sheet (the home page's translate button): a grab
  /// handle, the title and an X instead of the top bar.
  final bool asSheet;

  const TranslatorPage({
    super.key,
    this.translator,
    this.lookup = lookUpInLexicon,
    this.saved,
    this.asSheet = false,
  });

  @override
  State<TranslatorPage> createState() => _TranslatorPageState();
}

enum _Status { idle, preparing, translating, failed, noTranslator }

class _TranslatorPageState extends State<TranslatorPage> {
  late final Translator _translator =
      widget.translator ??
      PreferredTranslator(
        ai: AiModel.instance,
        useAi: () => AppSettings.instance.aiTranslator,
        offline: OpusMtService.instance,
      );
  late final SavedTranslations _saved =
      widget.saved ?? PhoneSavedTranslations.instance;

  /// The latest machine translation, saved once the person is done with the
  /// text (Enter, copy, listen, swap, clear, paste, leaving the page) — not
  /// every step of live typing ("Where is the" on the way to "Where is the
  /// beach?").
  ({String text, String translation, String from, String to})? _unsaved;

  /// Saves [_unsaved] if it's still the text in the box.
  void _keep() {
    final u = _unsaved;
    if (u == null || savedKey(u.text) != savedKey(_input.text)) return;
    _unsaved = null;
    _saved
        .save(u.text, u.translation, from: u.from, to: u.to)
        .catchError((Object e) => debugPrint('Translator: not saved: $e'));
  }

  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  // The two languages; set on first build: from the app's language into
  // the second language (or English / Greek).
  String? _from;
  String? _toChoice;
  String get _to => _toChoice!;
  String _output = '';

  /// The dictionary's meanings when the text is a word it knows; empty
  /// otherwise. The translation itself always comes from the translator.
  List<WordTranslation> _meanings = const [];
  _Status _status = _Status.idle;
  Future<void>? _ready;

  /// How long typing must pause before the live translation runs.
  static const liveDelay = Duration(milliseconds: 350);
  Timer? _liveTimer;

  /// Counts translation requests, so a slow, older result never replaces
  /// a newer one.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    // Start fetching the language models straight away (first time only),
    // so they're likely there by the time something is typed.
    // A failure here shows on the page; the next translation tries again.
    _ready = _prepare()..ignore();
    // The AI model, when it's on, takes a while to load: start now.
    if (_translator case final PreferredTranslator t) t.warmUp().ignore();
    _input.addListener(_onTyping);
    if (widget.translator == null) {
      OpusMtService.instance.changes.addListener(_onDownload);
    }
  }

  /// The offline translator's download moved on: show its progress, and
  /// translate the waiting text once it's in.
  void _onDownload() {
    if (!mounted || _status != _Status.noTranslator) return;
    if (OpusMtService.instance.state == ModelState.ready) {
      _translate();
    } else {
      setState(() {});
    }
  }

  String _lastText = '';

  /// Live translation: shortly after typing pauses, translate what's there.
  void _onTyping() {
    // Enter from a hardware keyboard types a new line instead of pressing
    // ✓: take it out and translate, like ✓ does.
    if (_input.text.contains('\n')) {
      final cleaned = _input.text.replaceAll('\n', ' ').trimRight();
      _input.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
      _submit();
      return;
    }
    final text = _input.text.trim();
    if (text == _lastText) return; // only the cursor moved
    _lastText = text;
    _liveTimer?.cancel();
    if (text.isEmpty) {
      _request++; // drop any translation still on its way
      setState(() {
        _output = '';
        _meanings = const [];
        if (_status != _Status.preparing) _status = _Status.idle;
      });
      return;
    }
    setState(() {}); // ✕ and the 🔊 / copy row appear once there is text
    _liveTimer = Timer(liveDelay, _translate);
  }

  Future<void> _prepare() async {
    try {
      if (await _translator.isReady()) return;
      if (mounted) setState(() => _status = _Status.preparing);
      await _translator.prepare();
      if (mounted && _status == _Status.preparing) {
        setState(() => _status = _Status.idle);
      }
    } catch (_) {
      if (mounted) setState(() => _status = _Status.failed);
      _ready = null; // try again on the next translation
      rethrow;
    }
  }

  @override
  void dispose() {
    _keep(); // leaving the page: the last text is done
    _liveTimer?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    if (widget.translator == null) {
      _translator.dispose();
      OpusMtService.instance.changes.removeListener(_onDownload);
    }
    super.dispose();
  }

  /// Translate what's typed now. The previous translation stays on screen
  /// until the new one arrives, so live updates don't flicker.
  Future<void> _translate() async {
    _liveTimer?.cancel();
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final request = ++_request;
    final from = _from!, to = _to;
    if (_output.isEmpty && _status != _Status.preparing) {
      setState(() => _status = _Status.translating);
    }
    try {
      // A word or phrase the lexicon knows is answered from the lexicon
      // (instantly, no machine); anything else by the translator.
      // A lexicon that can't be read doesn't stop the translation.
      const none = (main: null, meanings: <WordTranslation>[]);
      // (The lexicon's translations are English ↔ Greek only.)
      final englishGreek = {from, to}.containsAll(const ['en', 'el']);
      final known = englishGreek
          ? await widget.lookup(text, from).catchError((Object e) {
              debugPrint('Translator: lexicon lookup failed: $e');
              return none as LexiconAnswer;
            })
          : none;
      if (!mounted || request != _request) return;
      // Otherwise: translated before on this phone (instant, offline), or
      // the translator (and remembered once the text is done).
      String? answer = known.main;
      var fromMachine = false;
      answer ??= await _saved
          .find(text, from: from, to: to)
          .catchError((Object e) => null);
      // A saved "translation" that only repeats the text (an older AI
      // slip) is translated again.
      if (answer != null && AiModel.isCopy(answer, text)) {
        answer = null;
      }
      if (answer == null) {
        await (_ready ??= _prepare());
        answer = await _translator.translate(text, from: from, to: to);
        fromMachine = true;
      }
      if (!mounted || request != _request) return; // a newer one is coming
      final shown = answer;
      _unsaved = fromMachine
          ? (text: text, translation: shown, from: from, to: to)
          : null;
      setState(() {
        _output = shown;
        _meanings = known.meanings;
        _status = _Status.idle;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(
          () => _status = e is NoTranslatorYet
              ? _Status.noTranslator
              : _Status.failed,
        );
        // Not downloaded (no internet at start, say): try again now.
        if (e is NoTranslatorYet && widget.translator == null) {
          OpusMtService.instance.ensure().ignore();
        }
      }
    }
  }

  /// Enter on the keyboard: translate right away and close the keyboard.
  void _submit() {
    _inputFocus.unfocus();
    _translate().then((_) => _keep());
  }

  /// The languages the translator can use now: English, Greek, and the
  /// downloaded ones.
  List<String> get _usable => [
    for (final l in appLanguages)
      if (l.available) l.code,
  ];

  /// A language pill: with only two languages it swaps them; with more, it
  /// lists them to pick from (picking the other side's language swaps).
  Future<void> _pick({required bool source}) async {
    final usable = _usable;
    if (usable.length <= 2) return _swap();
    final current = source ? _from : _to;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final code in usable)
              ListTile(
                key: Key('pick-language-$code'),
                leading: FlagIcon.has(code) ? FlagIcon(code, size: 36) : null,
                title: Text(AppText.of(c).languageName(code)),
                trailing: code == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(c).pop(code),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current || !mounted) return;
    if (picked == (source ? _to : _from)) return _swap();
    _keep();
    setState(() {
      if (source) {
        _from = picked;
      } else {
        _toChoice = picked;
      }
      _output = '';
      _meanings = const [];
    });
    if (_input.text.trim().isNotEmpty) _translate();
  }

  /// Swap the languages: the translation becomes the text to translate.
  void _swap() {
    _keep();
    _liveTimer?.cancel();
    setState(() {
      final from = _from;
      _from = _to;
      _toChoice = from;
      if (_output.isNotEmpty) {
        _lastText = _output.trim(); // not typing: no live delay
        _input.text = _output;
        _output = '';
        _meanings = const [];
      }
      if (_status == _Status.failed) _status = _Status.idle;
    });
    if (_input.text.trim().isNotEmpty) _translate();
  }

  Future<void> _speak(String text, String language) async {
    if (text.trim().isEmpty) return;
    _keep();
    final accent = Accent.forLanguage(language).first;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await Speech.instance.say(text, accent);
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(
          content: DualText(
            (t) => t.noVoice(accent.name),
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

  /// Paste the clipboard's text in; it translates like typed text.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _translate().then((_) => _keep()); // a pasted text is a finished one
  }

  /// ✕: empty the text (and so the translation) and start typing again.
  void _clear() {
    _keep();
    _input.clear();
    _inputFocus.requestFocus();
  }

  Future<void> _copy(String text) async {
    if (text.trim().isEmpty) return;
    _keep();
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: DualText(
            (t) => t.copied,
            style: const TextStyle(color: Colors.white),
            secondaryStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    _from ??= AppText.of(context).code;
    _toChoice ??= () {
      final second = AppSettings.instance.secondaryLanguage;
      if (second != null && second != _from && _usable.contains(second)) {
        return second;
      }
      return _from == 'en' ? 'el' : 'en';
    }();
    final t = AppText.of(context);
    final brightness = Theme.of(context).brightness;
    final paper = brightness.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final gridCell = brightness.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final serif = Theme.of(context).textTheme.bodyLarge!;
    final big = serif.copyWith(fontSize: 30, height: 1.25, color: ink);
    final labelStyle = Theme.of(context).textTheme.labelMedium!
        .copyWith(color: muted);
    final hasText = _input.text.trim().isNotEmpty;

    // What the translation part shows: the result, or what is happening.
    String? message;
    switch (_status) {
      case _Status.preparing:
        message = t.preparingTranslator;
      case _Status.translating:
        message = t.translating;
      case _Status.failed:
        message = t.translateFailed;
      case _Status.noTranslator:
        final opus = OpusMtService.instance;
        message = opus.state == ModelState.downloading
            ? t.translatorDownloading((opus.progress * 100).floor())
            : t.noTranslatorYet;
      case _Status.idle:
        message = null;
    }
    final showResult = hasText || message != null;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── In a sheet: grab handle, title, X ──────────────────────────
            if (widget.asSheet)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.sm,
                  Spacing.sm,
                  0,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: hairline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          // Big and bold, like the other pages' titles.
                          child: DualText(
                            (t) => AppText.upper(t.translator),
                            inline: true,
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                        ),
                        IconButton(
                          key: const Key('translator-sheet-close'),
                          icon: Icon(Icons.close, color: ink),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            // ── Top bar: Back, dictionary search, 🌐, Home ─────────────────
            else
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
                      key: const Key('translator-back'),
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
                    const Expanded(
                      child: DictionarySearchBar(
                        fieldKey: Key('translator-search'),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    const LanguageButton(),
                  ],
                ),
              ),

            // ── The text and its translation ───────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.md,
                  Spacing.lg,
                  Spacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The page's title (the sheet has it in its header).
                    if (!widget.asSheet) ...[
                      DualText(
                        (t) => AppText.upper(t.translator),
                        style: Theme.of(context).textTheme.displayLarge,
                        inline: true,
                      ),
                      const SizedBox(height: Spacing.md),
                    ],
                    // Source language, and ✕ once there is text.
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.languageName(_from!),
                            key: const Key('source-label'),
                            style: labelStyle,
                          ),
                        ),
                        if (hasText)
                          _IconAction(
                            key: const Key('clear-input'),
                            icon: Icons.close,
                            tooltip: t.clear,
                            color: ink,
                            onTap: _clear,
                          ),
                      ],
                    ),
                    TextField(
                      key: const Key('translator-input'),
                      controller: _input,
                      focusNode: _inputFocus,
                      minLines: 1,
                      maxLines: null,
                      // Enter translates (no new lines).
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: big,
                      decoration: InputDecoration(
                        hintText: t.translateTextHint,
                        hintStyle: big.copyWith(color: muted),
                        // No outline (the app theme adds one).
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: Spacing.sm,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    if (!hasText)
                      // Empty: offer to paste.
                      ActionChip(
                        key: const Key('paste-button'),
                        avatar: Icon(Icons.content_paste, size: 18, color: ink),
                        label: Text(t.paste),
                        labelStyle: Theme.of(context).textTheme.labelLarge!
                            .copyWith(color: ink),
                        backgroundColor: gridCell,
                        side: BorderSide(color: hairline),
                        shape: const StadiumBorder(),
                        onPressed: _paste,
                      )
                    else
                      _ActionRow(
                        speakKey: const Key('speak-input'),
                        copyKey: const Key('copy-input'),
                        speakTooltip: t.speak,
                        copyTooltip: t.copy,
                        color: ink,
                        onSpeak: () => _speak(_input.text, _from!),
                        onCopy: () => _copy(_input.text),
                      ),

                    if (showResult) ...[
                      // A short line between the text and its translation.
                      Center(
                        child: Container(
                          width: 160,
                          height: 1,
                          margin: const EdgeInsets.symmetric(
                            vertical: Spacing.lg,
                          ),
                          color: hairline,
                        ),
                      ),
                      Text(
                        t.languageName(_to),
                        key: const Key('target-label'),
                        style: labelStyle,
                      ),
                      const SizedBox(height: Spacing.sm),
                      SelectableText(
                        message ?? _output,
                        key: const Key('translator-output'),
                        style: message == null
                            ? big // the translation, in ink like the text above
                            : serif.copyWith(color: muted, fontSize: 16),
                      ),
                      if (message == null && _output.isNotEmpty) ...[
                        const SizedBox(height: Spacing.md),
                        _ActionRow(
                          speakKey: const Key('speak-output'),
                          copyKey: const Key('copy-output'),
                          speakTooltip: t.speak,
                          copyTooltip: t.copy,
                          color: ink,
                          onSpeak: () => _speak(_output, _to),
                          onCopy: () => _copy(_output),
                        ),
                        if (_meanings.isNotEmpty) ...[
                          const SizedBox(height: Spacing.lg),
                          _MeaningsBox(meanings: _meanings),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // ── Language bar: [English] ⇄ [Greek] ───────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.md,
              ),
              decoration: BoxDecoration(
                color: paper,
                border: Border(top: BorderSide(color: hairline, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _LanguagePill(
                      key: const Key('from-language'),
                      label: t.languageName(_from!),
                      onTap: () => _pick(source: true),
                    ),
                  ),
                  IconButton(
                    key: const Key('swap-button'),
                    tooltip: t.swapLanguages,
                    onPressed: _swap,
                    icon: Icon(Icons.swap_horiz, color: ink),
                  ),
                  Expanded(
                    child: _LanguagePill(
                      key: const Key('to-language'),
                      label: t.languageName(_to),
                      onTap: () => _pick(source: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔊 on the left, copy on the right, under a text.
class _ActionRow extends StatelessWidget {
  final Key speakKey;
  final Key copyKey;
  final String speakTooltip;
  final String copyTooltip;
  final Color color;
  final VoidCallback onSpeak;
  final VoidCallback onCopy;

  const _ActionRow({
    required this.speakKey,
    required this.copyKey,
    required this.speakTooltip,
    required this.copyTooltip,
    required this.color,
    required this.onSpeak,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _IconAction(
          key: speakKey,
          icon: Icons.volume_up_outlined,
          tooltip: speakTooltip,
          color: color,
          onTap: onSpeak,
        ),
        _IconAction(
          key: copyKey,
          icon: Icons.copy_outlined,
          tooltip: copyTooltip,
          color: color,
          onTap: onCopy,
        ),
      ],
    );
  }
}

/// A plain icon button (no fill).
class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _IconAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, color: color, size: 26),
  );
}

/// One language in the bottom bar; tapping it swaps the languages.
class _LanguagePill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LanguagePill({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness.resolve(
        light: AppColors.gridCellLight,
        dark: AppColors.gridCellDark,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radius.lg),
        side: BorderSide(
          color: brightness.resolve(
            light: AppColors.hairlineLight,
            dark: AppColors.hairlineDark,
          ),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge!.copyWith(
                color: brightness.resolve(
                  light: AppColors.inkLight,
                  dark: AppColors.inkDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Dictionary": the word's meanings in the other language, one line per
/// meaning ("noun   house, home").
class _MeaningsBox extends StatelessWidget {
  final List<WordTranslation> meanings;

  const _MeaningsBox({required this.meanings});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final brightness = Theme.of(context).brightness;
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    final body = Theme.of(context).textTheme.bodyLarge!.copyWith(color: ink);
    final tag = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: muted, fontStyle: FontStyle.italic);

    Widget line(String left, String right, {Key? key, bool faded = false}) =>
        Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: Text(left, style: tag)),
              Expanded(
                child: Text(
                  right,
                  style: faded ? body.copyWith(color: muted) : body,
                ),
              ),
            ],
          ),
        );

    return Container(
      key: const Key('meanings-box'),
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppText.upper(t.dictionary),
            style: kickerStyle(brightness: brightness),
          ),
          const SizedBox(height: Spacing.sm),
          for (final m in meanings)
            line(t.partOfSpeechName(m.pos), m.words.join(', ')),
        ],
      ),
    );
  }
}
