// ─────────────────────────────────────────────────────────────────────────────
// DICTIONARY SEARCH BAR — the top-bar field that looks a word up: pressing the
// keyboard's search key, or the magnifier, opens the Dictionary page with the
// word searched
// ─────────────────────────────────────────────────────────────────────────────

import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
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

    return Container(
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
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
          decoration: InputDecoration(
            hintText: dualString(context, (t) => t.searchDictionaryHint),
            hintStyle: TextStyle(fontSize: 14, color: muted),
            // Pressing the magnifier searches, like the keyboard's key.
            prefixIcon: IconButton(
              key: const Key('search-icon'),
              icon: Icon(Icons.search, size: 20, color: muted),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
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
              child: const SizedBox.square(
                dimension: 40,
                child: SectionIcon(Section.dictionary, size: 40, compact: true),
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
