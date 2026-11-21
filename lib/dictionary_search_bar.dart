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
import 'dictionary_page.dart';

class DictionarySearchBar extends StatefulWidget {
  /// Key for the text field itself (tests find the field by it).
  final Key? fieldKey;

  const DictionarySearchBar({super.key, this.fieldKey});

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
