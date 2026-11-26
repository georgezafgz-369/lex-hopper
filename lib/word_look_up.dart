// ─────────────────────────────────────────────────────────────────────────────
// DOUBLE-TAP A WORD — anywhere in the app, opens its page in the dictionary
// ─────────────────────────────────────────────────────────────────────────────
//
// One listener wraps the whole app (main.dart). It only watches the taps, so
// every button and list keeps working as before; when two taps land on the
// same word of a text, it opens that word's page. Settings turns it off.
// Places where a double tap means something else (the game grids, the
// Clear | Hint | Check pill) are wrapped in [NoWordLookUp].

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'dictionary_page.dart' show showDictionarySheet;
import 'dictionary_service.dart';
import 'word_sheet.dart' show showWordSheet;

class WordLookUp extends StatefulWidget {
  /// The app's navigator, to open the sheet over the current page.
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  const WordLookUp({super.key, required this.navigator, required this.child});

  /// When the last double tap found a word: pages that do something on a
  /// double tap of their own (the crossword's clues) skip it then.
  static DateTime lookedUpAt = DateTime(0);

  /// Tests put their own here in place of opening the dictionary.
  @visibleForTesting
  static void Function(String word)? onLookUpForTest;

  static bool get justLookedUp =>
      DateTime.now().difference(lookedUpAt) < const Duration(milliseconds: 500);

  /// The word at [offset] in [text], or null when it's on no word.
  @visibleForTesting
  static String? wordAt(String text, int offset) {
    for (final m in _word.allMatches(text)) {
      // A tap on the right half of the last letter gives the word's end.
      if (offset >= m.start && offset <= m.end) return m.group(0);
    }
    return null;
  }

  // Letters in any alphabet, with ' or - inside (don't, well-known).
  static final _word = RegExp(r"\p{L}+(?:['’-]\p{L}+)*", unicode: true);

  /// The dictionaries to try for [word], most likely first: Greek letters
  /// read the Greek one, Cyrillic the Russian one; other words the app's
  /// language, the secondary language, then English (when they use Latin
  /// letters and are on the phone).
  @visibleForTesting
  static List<String> dictionariesFor(
    String word, {
    required String main,
    String? second,
  }) {
    if (RegExp(r'[Ͱ-Ͽἀ-῿]').hasMatch(word)) {
      return const ['el'];
    }
    if (RegExp('[Ѐ-ӿ]').hasMatch(word)) return const ['ru'];
    return {
      for (final code in [main, ?second, 'en'])
        if (code != 'el' && code != 'ru') code,
    }.toList();
  }

  @override
  State<WordLookUp> createState() => _WordLookUpState();
}

class _WordLookUpState extends State<WordLookUp> {
  // The last tap: when and where it went up, and the word it was on. (The
  // word, not the text object: a first tap that selects a clue rebuilds
  // its text.)
  Duration? _lastUp;
  Offset _lastPosition = Offset.zero;
  String? _lastWord;

  static const _doubleTapTime = Duration(milliseconds: 300);
  static const _doubleTapSlop = 30.0;

  void _onUp(PointerUpEvent event) {
    if (!AppSettings.instance.wordLookUp) return;
    final word = _wordAt(event.position);
    final isDouble =
        word != null &&
        word == _lastWord &&
        _lastUp != null &&
        event.timeStamp - _lastUp! < _doubleTapTime &&
        (event.position - _lastPosition).distance < _doubleTapSlop;
    _lastUp = event.timeStamp;
    _lastPosition = event.position;
    _lastWord = word;
    if (!isDouble) return;
    _lastWord = null; // a third tap starts over
    if (word.runes.length < 2) return;
    WordLookUp.lookedUpAt = DateTime.now();
    final test = WordLookUp.onLookUpForTest;
    test != null ? test(word) : _open(word);
  }

  /// The word under [position], or null.
  String? _wordAt(Offset position) {
    final paragraph = _paragraphAt(position);
    if (paragraph == null) return null;
    final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final caret = paragraph.getPositionForOffset(
      paragraph.globalToLocal(position),
    );
    return WordLookUp.wordAt(text, caret.offset);
  }

  /// The text under [position], unless it's inside a [NoWordLookUp].
  RenderParagraph? _paragraphAt(Offset position) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final result = BoxHitTestResult();
    box.hitTest(result, position: box.globalToLocal(position));
    RenderParagraph? found;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is _RenderNoWordLookUp) return null;
      if (found == null && target is RenderParagraph) found = target;
    }
    return found;
  }

  Future<void> _open(String word) async {
    final settings = AppSettings.instance;
    final lower = word.toLowerCase();
    final services = [
      for (final code in WordLookUp.dictionariesFor(
        word,
        main: settings.languageCode,
        second: settings.secondaryLanguage,
      ))
        if (DictionaryService.forLanguage(code).language == code)
          DictionaryService.forLanguage(code), // only those on the phone
    ];
    Future<void> show(String found, String code) async {
      final context = widget.navigator.currentContext;
      if (context == null || !context.mounted) return;
      await showWordSheet(context, word: found, language: code);
    }

    // The word as written, in the likeliest dictionary first.
    for (final service in services) {
      if ((await service.entriesFor(lower)).isNotEmpty) {
        return show(lower, service.language);
      }
    }
    // Else its base form: the shortest word starting with the word less a
    // few letters at the end (produced → produce, έρχεται → έρχομαι).
    final letters = lower.characters.toList();
    for (final service in services) {
      for (var cut = 1; cut <= 4 && letters.length - cut >= 3; cut++) {
        final stem = letters.take(letters.length - cut).join();
        final found = await service.search(query: stem, limit: 1);
        if (found.isNotEmpty) {
          return show(found.first.word, service.language);
        }
      }
    }
    // Nothing close: the dictionary, searching for it.
    final context = widget.navigator.currentContext;
    if (context == null || !context.mounted) return;
    await showDictionarySheet(context, initialQuery: lower);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerUp: _onUp,
    child: widget.child,
  );
}

/// Double-tapping a word inside [child] doesn't open the dictionary (game
/// grids and buttons, where a double tap means something else).
class NoWordLookUp extends SingleChildRenderObjectWidget {
  const NoWordLookUp({super.key, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNoWordLookUp();
}

class _RenderNoWordLookUp extends RenderProxyBox {}
