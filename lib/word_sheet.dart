// ─────────────────────────────────────────────────────────────────────────────
// WORD PAGE — everything about one word, sliding up from the bottom
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'design_system.dart';
import 'dictionary_service.dart';
import 'dual_text.dart';
import 'speech.dart';

/// Opens the word page for [word] as a bottom sheet. [highlightId] marks the
/// meaning that was pressed. Pressing a synonym opens another word page on
/// top of this one.
Future<void> showWordSheet(
  BuildContext context, {
  required String word,
  int? highlightId,
  String? language,
}) {
  // The dictionary of the app's language, unless the caller picks one (the
  // crossword's answers are English words).
  final dictionary = language ?? AppText.of(context).code;
  return showDraggableSheet(
    context,
    builder: (scrollController) => WordDetailPage(
      word: word,
      highlightId: highlightId,
      language: dictionary,
      scrollController: scrollController,
    ),
  );
}

/// A sheet that opens at ~60% height. The user drags it (by its handle or
/// by scrolling its content) to any height between a quarter of the screen
/// and full screen, and it stays there. It closes with the X button, the
/// phone's Back button, or by pulling it on down from its smallest size
/// (a short pull springs back, so it doesn't close by accident).
Future<void> showDraggableSheet(
  BuildContext context, {
  required Widget Function(ScrollController scrollController) builder,
}) {
  const halfSize = 0.6;
  const minSize = 0.25;
  // Let go below this (pulled down from the smallest size) and it closes.
  const closeBelow = 0.17;
  final brightness = Theme.of(context).brightness;
  final paper = brightness.resolve(
    light: AppColors.paperLight,
    dark: AppColors.paperDark,
  );
  final hairline = brightness.resolve(
    light: AppColors.hairlineLight,
    dark: AppColors.hairlineDark,
  );
  final muted = brightness.resolve(
    light: AppColors.mutedLight,
    dark: AppColors.mutedDark,
  );
  final sheet = DraggableScrollableController();
  var closed = false;

  // Close only this sheet, never the page under it.
  void close(BuildContext sheetContext) {
    if (closed) return;
    if (ModalRoute.of(sheetContext)?.isCurrent ?? false) {
      closed = true;
      Navigator.of(sheetContext).pop();
    }
  }

  // After a drag: below the smallest size, close it if pulled far enough
  // (or flicked down), otherwise spring back to the smallest size.
  void settle(BuildContext sheetContext, {double velocity = 0}) {
    if (closed || !sheet.isAttached) return;
    final size = sheet.size;
    if (size >= minSize - 0.001) return;
    if (size < closeBelow || velocity > 700) {
      close(sheetContext);
    } else {
      sheet.animateTo(
        minSize,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Tapping outside or dragging down doesn't close it; the X does.
    isDismissible: false,
    enableDrag: false,
    backgroundColor: paper,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: ui.Radius.circular(Radius.lg)),
    ),
    builder: (sheetContext) => Padding(
      // Keep the content above the on-screen keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: DraggableScrollableSheet(
        controller: sheet,
        expand: false,
        initialChildSize: halfSize,
        // It can be pulled below [minSize] only to close it (see settle).
        minChildSize: 0.0,
        maxChildSize: 1.0,
        shouldCloseOnMinExtent: false,
        builder: (_, scrollController) =>
            NotificationListener<ScrollEndNotification>(
              // Let go after dragging the content (and the sheet with it).
              onNotification: (_) {
                settle(sheetContext);
                return false;
              },
              // While it is pulled down to close, the sheet can get shorter
              // than its top bar: keep the contents' full layout and clip.
              child: LayoutBuilder(
                builder: (_, box) => ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: max(box.maxHeight, 120),
                    maxHeight: max(box.maxHeight, 120),
                    child: Column(
                      children: [
                        // Top bar: drag handle in the middle, X on the right.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (d) {
                            if (closed || !sheet.isAttached) return;
                            final size =
                                sheet.size - sheet.pixelsToSize(d.delta.dy);
                            sheet.jumpTo(size.clamp(0.0, 1.0));
                          },
                          onVerticalDragEnd: (d) => settle(
                            sheetContext,
                            velocity: d.velocity.pixelsPerSecond.dy,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: hairline,
                                    borderRadius: BorderRadius.circular(
                                      Radius.sm,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: Spacing.xs,
                                  top: 0,
                                  bottom: 0,
                                  child: IconButton(
                                    tooltip: AppText.of(sheetContext).close,
                                    icon: Icon(
                                      Icons.close,
                                      size: 22,
                                      color: muted,
                                    ),
                                    onPressed: () => close(sheetContext),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: builder(scrollController)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    ),
  ).whenComplete(sheet.dispose);
}

// ── Label tags (shared with the dictionary result cards) ──────────────────

/// Subject label, e.g. "Law / Legal": a filled tag.
class SubjectTag extends StatelessWidget {
  final String text;
  const SubjectTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.claretLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.claretLight,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

/// Usage label, e.g. "Slang" or "From Yiddish": an outlined italic tag, the
/// way printed dictionaries mark them.
class UsageTag extends StatelessWidget {
  final String text;
  final Color color;
  const UsageTag(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: color,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

/// Subject name and usage names (plus "From" + origin) for an entry.
({String? subject, List<String> usages}) entryLabels(
  DictionaryEntry entry,
  FilterOptions? options, {
  AppText t = AppText.english,
}) {
  final subject = entry.subject == null
      ? null
      : options?.subjectsById[entry.subject]?.name(t.code) ?? entry.subject;
  return (
    subject: subject,
    usages: [
      for (final id in entry.usages) options?.usageById[id]?.name(t.code) ?? id,
      if (entry.origin != null) t.fromLanguage(entry.origin!),
      if (entry.code != null) entry.code!,
    ],
  );
}

// ── Word page ─────────────────────────────────────────────────────────────

class WordDetailPage extends StatefulWidget {
  final String word;

  /// The meaning that was pressed; it is highlighted and scrolled to.
  final int? highlightId;

  /// The sheet's scroll controller, so scrolling also drags the sheet.
  final ScrollController? scrollController;

  /// Which dictionary to read: "en" or "el".
  final String language;

  const WordDetailPage({
    super.key,
    required this.word,
    this.highlightId,
    this.scrollController,
    this.language = 'en',
  });

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  /// The app's text in the current language.
  AppText get _t => AppText.of(context);

  /// The dictionary this page reads (English or Greek).
  DictionaryService get _service =>
      DictionaryService.forLanguage(widget.language);

  /// The word shown: [WordDetailPage.word] as the dictionary writes it.
  late String _word = widget.word;

  List<DictionaryEntry>? _entries;
  List<DictionaryEntry> _phrases = const [];
  Map<int, List<String>> _aliases = const {};

  /// The other language of this dictionary: Greek for English, English for
  /// Greek and for the downloaded languages.
  String get _other => widget.language == 'en' ? 'el' : 'en';

  /// Translations into the other language show only when it is set as the
  /// second language (Settings > Language).
  bool get _showOther => AppSettings.instance.secondaryLanguage == _other;

  /// The word in the other language: its main translation (from the
  /// lexicon, as the Translator shows it) and, per meaning, that meaning's
  /// words in the other language.
  String? _translation;
  Map<int, List<String>> _linked = const {};
  List<String> _moreExamples = const [];
  WordInfo _info = const WordInfo();
  FilterOptions? _options;
  final _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _service.entriesFor(widget.word);
    // The word as the dictionary writes it (a Greek crossword answer ΣΠΙΤΙ
    // opens σπίτι).
    final word = entries.isEmpty ? widget.word : entries.first.word;
    final results = await Future.wait([
      FilterOptions.load(),
      _service.phrasesWith(word),
    ]);
    if (!mounted) return;
    setState(() {
      _word = word;
      _entries = entries;
      _options = results[0] as FilterOptions;
      _phrases = results[1] as List<DictionaryEntry>;
    });
    // Other names (medical aliases) and extra example sentences.
    final service = _service;
    final ids = _entries!.map((e) => e.id).toList();
    final aliases = await service.aliasesFor(ids);
    final more = await service.moreExamples(word);
    final info = await service.wordInfo(word);
    final translation = await service.mainTranslation(word);
    final linked = await service.linkedWords(ids);
    if (!mounted) return;
    setState(() {
      _aliases = aliases;
      _moreExamples = more;
      _info = info;
      _translation = translation;
      _linked = linked;
    });
    // Bring the pressed meaning into view if it's further down.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (target == null || !target.mounted) return;
      // Leave the page at the top (showing the word) when the meaning is
      // already in view; otherwise scroll it near the top.
      final box = target.findRenderObject() as RenderBox?;
      final viewport = Scrollable.maybeOf(target)?.context.findRenderObject();
      if (box != null && viewport is RenderBox) {
        final y = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
        if (y + box.size.height < viewport.size.height) return;
      }
      {
        Scrollable.ensureVisible(
          target,
          alignment: 0.05,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
    final gridCell = brightness.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );

    final entries = _entries;
    if (entries == null) {
      return ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.only(top: Spacing.xxl),
        children: const [Center(child: CircularProgressIndicator())],
      );
    }

    // Group meanings by part of speech, keeping display order.
    final byPos = <String, List<DictionaryEntry>>{};
    for (final e in entries) {
      byPos.putIfAbsent(e.partOfSpeech, () => []).add(e);
    }

    // Word-level facts, taken from any meaning that has them.
    final structureId = entries
        .map((e) => e.structure)
        .firstWhere((s) => s != null, orElse: () => null);
    final structure = structureId == null
        ? null
        : _options?.structures.where((s) => s.id == structureId).firstOrNull;
    final origins = {for (final e in entries) ?e.origin};
    final related = {
      for (final e in entries)
        for (final r in e.related)
          if (r != _word) r,
    }.toList();
    final meaningCount = entries.length;

    final headingStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: clay,
      fontFamily: 'Inter',
    );

    // A single column (not a lazy list) so the pressed meaning exists and
    // can be scrolled to even when it's far down.
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: the word, big and bold, like the pages' titles ──
          Text(
            _word,
            style: Theme.of(context).textTheme.displayLarge
                ?.copyWith(color: ink),
          ),
          // Pronunciation, like a printed dictionary: |ˈdɪkʃəˌnɛri|, with
          // buttons to hear it in an American or British voice.
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_info.ipa != null)
                Text(
                  '|${_info.ipa}|'
                  '${(_info.syllables ?? 0) > 1 ? '   ${dualString(context, (t) => t.syllables(_info.syllables!))}' : ''}',
                  style: TextStyle(
                    fontSize: 16,
                    color: muted,
                    fontFamily: 'Inter',
                  ),
                ),
              for (final accent in Accent.forLanguage(widget.language))
                _speakButton(accent, ink: ink, hairline: hairline),
            ],
          ),
          // The word in the other language: "Greek  σπίτι" (only with that
          // language set as the second language).
          if (_showOther && _translation != null) ...[
            const SizedBox(height: 6),
            Text.rich(
              key: const Key('word-translation'),
              TextSpan(
                children: [
                  TextSpan(
                    text: '${_t.languageName(_other)}  ',
                    style: TextStyle(
                      fontSize: 13,
                      color: muted,
                      fontFamily: 'Inter',
                    ),
                  ),
                  TextSpan(
                    text: _translation,
                    style: TextStyle(
                      fontSize: 20,
                      color: clay,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          DualText(
            (t) => [
              byPos.keys.map(t.partOfSpeechName).join(' · '),
              t.meanings(meaningCount),
            ].join('   —   '),
            style: TextStyle(fontSize: 13, color: muted, fontFamily: 'Inter'),
          ),
          if (entries.isEmpty) ...[
            const SizedBox(height: Spacing.lg),
            DualText(
              (t) => t.noEntryYet,
              style: TextStyle(fontSize: 15, color: muted, fontFamily: 'Inter'),
            ),
          ],

          // ── Meanings, by part of speech ──
          for (final pos in byPos.keys) ...[
            const SizedBox(height: Spacing.lg),
            DualText(
              (t) => AppText.upper(t.partOfSpeechName(pos)),
              style: headingStyle,
              inline: true,
            ),
            // Word forms: "plural dictionaries", "began, begun…".
            if (_info.forms[pos] case final forms?) ...[
              const SizedBox(height: 2),
              DualText(
                (t) => pos == 'noun' ? t.plural(forms) : forms,
                inline: pos == 'noun',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: muted,
                  fontFamily: 'Inter',
                ),
              ),
            ],
            const SizedBox(height: Spacing.xs),
            Divider(color: hairline, height: 1),
            const SizedBox(height: Spacing.sm),
            for (final (i, entry) in byPos[pos]!.indexed)
              _meaning(
                number: i + 1,
                entry: entry,
                highlighted: entry.id == widget.highlightId,
                ink: ink,
                muted: muted,
                clay: clay,
                gridCell: gridCell,
              ),
          ],

          // ── More examples (hand-picked use cases) ──
          if (_moreExamples.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            DualText((t) => t.moreExamples, style: headingStyle, inline: true),
            const SizedBox(height: Spacing.xs),
            Divider(color: hairline, height: 1),
            const SizedBox(height: Spacing.sm),
            for (final sentence in _moreExamples)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _sayable(
                  '“$sentence”',
                  widget.language,
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: muted,
                    height: 1.4,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
          ],

          // ── Phrases containing the word ──
          if (_phrases.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            DualText((t) => t.phrases, style: headingStyle, inline: true),
            const SizedBox(height: Spacing.xs),
            Divider(color: hairline, height: 1),
            const SizedBox(height: Spacing.sm),
            for (final phrase in _phrases)
              _phrase(phrase, ink: ink, muted: muted),
          ],

          // ── About the word ──
          if (structure != null ||
              origins.isNotEmpty ||
              related.isNotEmpty ||
              _info.adjectives.isNotEmpty) ...[
            const SizedBox(height: Spacing.lg),
            DualText((t) => t.aboutTheWord, style: headingStyle, inline: true),
            const SizedBox(height: Spacing.xs),
            Divider(color: hairline, height: 1),
            const SizedBox(height: Spacing.sm),
            if (structure != null)
              _fact(
                label: (t) => t.structureLabel,
                value: (t) => [
                  t.structureWord(structure.name(t.code)),
                  if (structure.description(t.code).isNotEmpty)
                    structure.description(t.code),
                ].join(' — '),
                ink: ink,
                muted: muted,
              ),
            if (origins.isNotEmpty)
              _fact(
                label: (t) => t.originLabel,
                value: (t) => t.borrowedFrom(origins.join(', ')),
                ink: ink,
                muted: muted,
              ),
            if (related.isNotEmpty) ...[
              const SizedBox(height: 4),
              _chipRow(
                (t) => t.relatedForms,
                related,
                muted: muted,
                clay: clay,
              ),
            ],
            // Word links: adjectives meaning "relating to" this word.
            if (_info.adjectives.isNotEmpty) ...[
              const SizedBox(height: 8),
              _chipRow(
                (t) => t.relatingToIt,
                _info.adjectives,
                muted: muted,
                clay: clay,
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// One numbered meaning with its labels, examples, synonyms and opposites.
  Widget _meaning({
    required int number,
    required DictionaryEntry entry,
    required bool highlighted,
    required Color ink,
    required Color muted,
    required Color clay,
    required Color gridCell,
  }) {
    final labels = entryLabels(entry, _options, t: _t);
    return Container(
      key: highlighted ? _highlightKey : null,
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: highlighted
          ? const EdgeInsets.all(Spacing.sm)
          : const EdgeInsets.symmetric(vertical: 4),
      decoration: highlighted
          ? BoxDecoration(
              color: gridCell,
              borderRadius: BorderRadius.circular(Radius.sm),
              border: Border(left: BorderSide(color: clay, width: 3)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: muted,
                height: 1.5,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (labels.subject != null || labels.usages.isNotEmpty) ...[
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (labels.subject != null) SubjectTag(labels.subject!),
                      for (final u in labels.usages) UsageTag(u, color: muted),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                _sectionLabel((t) => t.meaningLabel, muted),
                _sayable(
                  entry.meaning,
                  widget.language,
                  style: TextStyle(
                    fontSize: 15,
                    color: ink,
                    height: 1.5,
                    fontFamily: 'Inter',
                  ),
                ),
                // The meaning itself in the other language.
                if (entry.meaningTranslation case final tr? when _showOther)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _sayable(
                      tr,
                      _other,
                      key: Key('meaning-text-translation-${entry.id}'),
                      style: TextStyle(
                        fontSize: 14,
                        color: clay,
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                // This meaning in the other language: "→ κατοικία, οίκος".
                if (_linked[entry.id] case final words? when _showOther)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '→ ${words.take(6).join(', ')}',
                      key: Key('meaning-translation-${entry.id}'),
                      style: TextStyle(
                        fontSize: 15,
                        color: clay,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                // Example sentences, in italics like a printed dictionary.
                if (entry.examples.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _sectionLabel((t) => t.examplesLabel, muted),
                ],
                for (final (i, example) in entry.examples.indexed) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _sayable(
                      '“$example”',
                      widget.language,
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: muted,
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  // The example in the other language, just below it.
                  if (_showOther &&
                      i < entry.exampleTranslations.length &&
                      entry.exampleTranslations[i] != null)
                    _sayable(
                      entry.exampleTranslations[i]!,
                      _other,
                      key: Key('example-translation-${entry.id}-$i'),
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: clay,
                        height: 1.4,
                        fontFamily: 'Inter',
                      ),
                    ),
                ],
                if (_aliases[entry.id] case final names?) ...[
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${dualString(context, (t) => t.alsoCalled)}  ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: [
                            ...names.take(12),
                            if (names.length > 12)
                              dualString(
                                context,
                                (t) => t.moreCount(names.length - 12),
                              ),
                          ].join(' · '),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: muted,
                      height: 1.4,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
                if (entry.synonyms.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _chipRow(
                    (t) => t.synonyms,
                    entry.synonyms,
                    muted: muted,
                    clay: clay,
                  ),
                ],
                if (entry.antonyms.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _chipRow(
                    (t) => t.opposites,
                    entry.antonyms,
                    muted: muted,
                    clay: clay,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Says [text] in [accent]; tells the user when the phone has no voice
  /// for it.
  Future<void> _say(String text, Accent accent) async {
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

  /// A sentence in [language] with a small speaker at its end that reads
  /// it aloud.
  Widget _sayable(
    String text,
    String language, {
    required TextStyle style,
    Key? key,
  }) {
    final accent = Accent.forLanguage(language).first;
    final spoken = text.replaceAll(RegExp('[“”]'), '');
    return Text.rich(
      key: key,
      TextSpan(
        children: [
          TextSpan(text: text),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Semantics(
              button: true,
              label: _t.listen,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _say(spoken, accent),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 2, 4, 2),
                  child: Icon(
                    Icons.volume_up_outlined,
                    size: (style.fontSize ?? 14) + 2,
                    color: style.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      style: style,
    );
  }

  /// "🔊 US" / "🔊 UK": says the word in that accent.
  Widget _speakButton(
    Accent accent, {
    required Color ink,
    required Color hairline,
  }) {
    return GestureDetector(
      key: Key('speak-${accent.label}'),
      onTap: () => _say(_word, accent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_up_outlined, size: 18, color: ink),
            const SizedBox(width: 4),
            Text(
              accent.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ink,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small bold heading inside a meaning, like "Meaning Σημασία".
  Widget _sectionLabel(TextPick label, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: DualText(
        label,
        inline: true,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: muted,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  /// A label followed by words that each open their own page.
  Widget _chipRow(
    TextPick label,
    List<String> words, {
    required Color muted,
    required Color clay,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        DualText(
          label,
          inline: true,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: muted,
            fontFamily: 'Inter',
          ),
        ),
        for (final word in words) _wordChip(word, clay),
      ],
    );
  }

  /// A phrase ("in a word") with its meaning; pressing it opens its page.
  Widget _phrase(
    DictionaryEntry phrase, {
    required Color ink,
    required Color muted,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          showWordSheet(context, word: phrase.word, language: widget.language),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: phrase.word,
                style: TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
              TextSpan(text: '  ${phrase.meaning}'),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: muted,
            height: 1.4,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  /// A word that opens its own page on top of this one.
  Widget _wordChip(String word, Color clay) {
    return GestureDetector(
      onTap: () =>
          showWordSheet(context, word: word, language: widget.language),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: clay, width: 0.8),
        ),
        child: Text(
          word,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: clay,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  /// "Origin  From Yiddish": a bold label and its value. With a secondary
  /// language, the label's translation follows it and the value's
  /// translation sits on a smaller line underneath.
  Widget _fact({
    required TextPick label,
    required TextPick value,
    required Color ink,
    required Color muted,
  }) {
    final second = secondaryText(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${label(_t)}  ',
                  style: TextStyle(fontWeight: FontWeight.w700, color: muted),
                ),
                if (second != null)
                  TextSpan(
                    text: '${label(second)}  ',
                    style: TextStyle(
                      fontSize: 11,
                      color: translationColor(context),
                    ),
                  ),
                TextSpan(text: value(_t)),
              ],
            ),
            style: TextStyle(
              fontSize: 14,
              color: ink,
              height: 1.4,
              fontFamily: 'Inter',
            ),
          ),
          if (second != null)
            Text(
              value(second),
              style: TextStyle(
                fontSize: 12,
                color: translationColor(context),
                fontFamily: 'Inter',
              ),
            ),
        ],
      ),
    );
  }
}
