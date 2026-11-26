// ─────────────────────────────────────────────────────────────────────────────
// DICTIONARY SEARCH BAR — the top-bar field that looks a word up: pressing the
// keyboard's search key, or the magnifier, opens the Dictionary page with the
// word searched
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_settings.dart';
import 'word_sheet.dart' show showWordSheet;
import 'dictionary_service.dart';
import 'app_text.dart';
import 'dual_text.dart';
import 'design_system.dart';
import 'section_icon.dart';
import 'dictionary_page.dart';

class DictionarySearchBar extends StatefulWidget {
  /// Key for the text field itself (tests find the field by it).
  final Key? fieldKey;

  /// Puts the cursor in it (and the keyboard up) at once.
  final bool autofocus;

  /// When given, a ✕ at the end empties it and calls this (folds it back
  /// into the dictionary icon, see DictionarySearchToggle).
  final VoidCallback? onClose;

  const DictionarySearchBar({
    super.key,
    this.fieldKey,
    this.autofocus = false,
    this.onClose,
  });

  @override
  State<DictionarySearchBar> createState() => _DictionarySearchBarState();
}

class _DictionarySearchBarState extends State<DictionarySearchBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Up to six words starting with [text], most common first, from the
  /// dictionary of its
  /// alphabet (Greek, Cyrillic), else the app's language, the secondary
  /// one and English, those on the phone.
  Future<List<WordSuggestion>> _suggest(String text) async {
    final query = text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final main = AppText.of(context).code;
    final codes = suggestionDictionaries(
      query,
      main: main,
      second: AppSettings.instance.secondaryLanguage,
    );
    final out = <WordSuggestion>[];
    final seen = <String>{};
    for (final code in codes) {
      final service = DictionaryService.forLanguage(code);
      if (service.language != code) continue; // not on the phone
      try {
        // The most common first (see DictionaryService.suggestions).
        for (final word in await service.suggestions(query)) {
          if (!seen.add(word.toLowerCase())) continue;
          out.add((word: word, language: code));
          if (out.length == 6) return out;
        }
      } catch (_) {}
    }
    return out;
  }

  /// A suggestion picked: its page in the dictionary.
  void _openWord(WordSuggestion s) {
    _controller.clear();
    _focusNode.unfocus();
    showWordSheet(context, word: s.word, language: s.language);
  }

  void _search(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    _controller.clear();
    _focusNode.unfocus();
    // A tap on the magnifier also reaches the text field, which takes the
    // focus back right after; drop it once more after this frame, or the
    // field is still selected (keyboard up) on coming back.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.unfocus();
    });
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DictionaryPage(initialQuery: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );

    // Words that begin with what's typed, under the field, as it's typed.
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<WordSuggestion>(
        textEditingController: _controller,
        focusNode: _focusNode,
        optionsBuilder: (value) => _suggest(value.text),
        displayStringForOption: (s) => s.word,
        onSelected: _openWord,
        optionsViewBuilder: (context, onSelected, options) => _Suggestions(
          width: constraints.maxWidth,
          options: options.toList(),
          onSelected: onSelected,
        ),
        fieldViewBuilder: (context, controller, focusNode, _) => Container(
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
          // Rebuilds when the secondary language changes (the hint shows both
          // languages).
          child: ListenableBuilder(
            listenable: AppSettings.instance,
            builder: (context, _) => TextField(
              key: widget.fieldKey,
              controller: controller,
              focusNode: focusNode,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: dualString(context, (t) => t.searchDictionaryHint),
                hintStyle: TextStyle(fontSize: 14, color: muted),
                // Pressing the magnifier searches, like the keyboard's key.
                prefixIcon: IconButton(
                  key: const Key('search-icon'),
                  icon: DoodleMagnifier(color: muted),
                  tooltip: AppText.of(context).search,
                  onPressed: () => _search(_controller.text),
                ),
                suffixIcon: widget.onClose == null
                    ? null
                    : IconButton(
                        key: const Key('search-close'),
                        icon: Icon(Icons.close, size: 18, color: muted),
                        tooltip: AppText.of(context).close,
                        onPressed: () {
                          _controller.clear();
                          _focusNode.unfocus();
                          widget.onClose!();
                        },
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                ),
              ),
              style: TextStyle(
                fontSize: 14,
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

/// Beside a Back button: the dictionary's doodle. Tapped, it opens into a
/// search bar as wide as the row, with the keyboard up; only the bar's ✕
/// folds it back into the doodle.
class DictionarySearchToggle extends StatefulWidget {
  /// The search field's key (tests find it by it).
  final Key? fieldKey;

  /// Beside the doodle while it's folded (the page's title); the open bar
  /// takes its place.
  final Widget? beside;

  /// The bar to open into, instead of the plain dictionary search (the
  /// Dictionary page's own field); [close] folds it back.
  final Widget Function(BuildContext context, VoidCallback close)? bar;

  /// Told when it opens (true) or folds (false).
  final ValueChanged<bool>? onOpenChanged;

  /// Open from the start.
  final bool initiallyOpen;

  const DictionarySearchToggle({
    super.key,
    this.fieldKey,
    this.beside,
    this.bar,
    this.onOpenChanged,
    this.initiallyOpen = false,
  });

  @override
  State<DictionarySearchToggle> createState() => _DictionarySearchToggleState();
}

class _DictionarySearchToggleState extends State<DictionarySearchToggle> {
  late bool _open = widget.initiallyOpen;

  void _set(bool open) {
    setState(() => _open = open);
    widget.onOpenChanged?.call(open);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_open) {
      child =
          widget.bar?.call(context, () => _set(false)) ??
          DictionarySearchBar(
            fieldKey: widget.fieldKey,
            autofocus: true,
            onClose: () => _set(false),
          );
    } else {
      child = Row(
        children: [
          Semantics(
            button: true,
            label: AppText.of(context).searchDictionaryHint,
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('dictionary-toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _set(true),
              // A rounded square, like the Back button beside it.
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness.resolve(
                    light: AppColors.gridCellLight,
                    dark: AppColors.gridCellDark,
                  ),
                  borderRadius: BorderRadius.circular(Radius.sm),
                ),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                // Drawn large: the doodle's blob fills most of the square.
                child: const OverflowBox(
                  maxWidth: 54,
                  maxHeight: 54,
                  child: SectionIcon(
                    Section.dictionary,
                    size: 54,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
          if (widget.beside != null) ...[
            const SizedBox(width: Spacing.sm),
            Expanded(child: widget.beside!),
          ],
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axis: Axis.horizontal,
          alignment: AlignmentDirectional.centerStart,
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(key: ValueKey(_open), child: child),
    );
  }
}

/// A suggested word and the dictionary it's in.
typedef WordSuggestion = ({String word, String language});

/// The dictionaries to suggest from for [query], likeliest first: Greek
/// letters the Greek one, Cyrillic the Russian one; other letters the
/// app's language, the secondary one and English (not Greek or Russian).
List<String> suggestionDictionaries(
  String query, {
  required String main,
  String? second,
}) {
  if (RegExp(r'[Ͱ-Ͽἀ-῿]').hasMatch(query)) return const ['el'];
  if (RegExp('[Ѐ-ӿ]').hasMatch(query)) return const ['ru'];
  return {
    for (final code in [main, ?second, 'en'])
      if (code != 'el' && code != 'ru') code,
  }.toList();
}

/// The list of suggested words under the search field.
class _Suggestions extends StatelessWidget {
  final double width;
  final List<WordSuggestion> options;
  final ValueChanged<WordSuggestion> onSelected;

  const _Suggestions({
    required this.width,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final card = b.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
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
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Material(
          key: const Key('search-suggestions'),
          color: card,
          elevation: 6,
          borderRadius: BorderRadius.circular(Radius.sm),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width, maxHeight: 280),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, _) => Divider(height: 0, color: hairline),
              itemBuilder: (context, i) {
                final s = options[i];
                return InkWell(
                  key: Key('suggestion-${s.word}'),
                  onTap: () => onSelected(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        DoodleMagnifier(color: muted, size: 16),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Text(
                            s.word,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: ink,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A hand-drawn magnifier: a slightly uneven lens with a glint, and its
/// handle.
class DoodleMagnifier extends StatelessWidget {
  final Color color;
  final double size;

  const DoodleMagnifier({super.key, required this.color, this.size = 20});

  @override
  Widget build(BuildContext context) {
    final c =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<g fill="none" stroke="$c" stroke-linecap="round" '
      'stroke-linejoin="round">'
      '<path d="M10.6 3.4 C14.8 3.1 17.8 6.3 17.3 10.4 C16.9 14.3 13.6 '
      '17.2 9.7 16.8 C5.9 16.4 3.3 13.2 3.7 9.5 C4.1 6.2 6.9 3.7 10.6 3.4 Z" '
      'stroke-width="2.3"/>'
      '<path d="M15.6 15.5 L20.8 20.6" stroke-width="2.8"/>'
      '<path d="M7.3 8.6 C7.8 7.2 9 6.4 10.4 6.3" stroke-width="1.6"/>'
      '</g></svg>',
      width: size,
      height: size,
    );
  }
}
