// ─────────────────────────────────────────────────────────────────────────────
// FIND THE WORDS — the letter grid, drag-to-select, and the word list
// ─────────────────────────────────────────────────────────────────────────────
//
// Drag from a word's first letter to its last (either way round). The line
// snaps to straight directions. A listed word stays marked in the next of
// five highlighter tints and is crossed off the list. Finding every word
// solves the level.

import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'design_system.dart';
import 'dual_text.dart';
import 'puzzle_themes.dart';
import 'word_search_maker.dart';
import 'word_search_puzzle.dart';
import 'word_search_save.dart';
import 'word_sheet.dart' show showWordSheet;

/// The five highlighter tints found words are marked with, in turn.
const wordSearchTints = [
  AppColors.wsClay,
  AppColors.wsOlive,
  AppColors.wsOchre,
  AppColors.wsSlate,
  AppColors.wsPlum,
];

class WordSearchGamePage extends StatefulWidget {
  final int startLevel;

  /// A ready puzzle (tests); otherwise one is made for [startLevel].
  final WordSearchPuzzle? puzzle;

  /// A saved game to continue (from the menu's Continue).
  final WordSearchProgress? resume;

  /// The subject chosen at New Game (null: all subjects). A resumed game
  /// takes the one it was saved with.
  final PuzzleTheme? theme;

  /// "en" or "el"; defaults to the app's language.
  final String? language;

  const WordSearchGamePage({
    super.key,
    this.startLevel = 1,
    this.puzzle,
    this.resume,
    this.language,
    this.theme,
  });

  @override
  State<WordSearchGamePage> createState() => _WordSearchGamePageState();
}

class _WordSearchGamePageState extends State<WordSearchGamePage> {
  late int _level =
      widget.resume?.puzzle.level ?? widget.puzzle?.level ?? widget.startLevel;
  WordSearchPuzzle? _puzzle;
  bool _loadFailed = false;

  /// This game's subject: the one saved with it, or the one chosen.
  late final PuzzleTheme? _theme = widget.resume != null
      ? widget.resume!.theme
      : widget.theme;

  late final String _language = widget.language ?? AppText.of(context).code;

  /// Found words, with the index of their tint.
  final Map<String, int> _found = {};

  /// True while a finger is on the grid: the page then doesn't scroll, so
  /// the drag selects letters instead of moving the page.
  bool _touchingGrid = false;

  /// The line being dragged: first and current square, as (row, col).
  (int, int)? _dragStart;
  (int, int)? _dragEnd;

  @override
  void initState() {
    super.initState();
    if (widget.resume case final saved?) {
      _puzzle = saved.puzzle;
      _found.addAll(saved.found);
    } else if (widget.puzzle != null) {
      _puzzle = widget.puzzle;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLevel(_level));
    }
  }

  Future<void> _startLevel(int level) async {
    setState(() {
      _level = level;
      _puzzle = null;
      _loadFailed = false;
      _found.clear();
      _dragStart = _dragEnd = null;
    });
    try {
      final puzzle = await WordSearchMaker.make(
        level,
        language: _language,
        theme: _theme,
      );
      if (!mounted) return;
      setState(() => _puzzle = puzzle);
      _save();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// Keep this game (and the words found so far) for Continue.
  void _save() {
    final puzzle = _puzzle;
    if (puzzle == null) return;
    WordSearchSave.save(
      WordSearchProgress(puzzle, Map.of(_found), _theme),
      language: _language,
    );
  }

  /// Open the word page of a found word.
  void _openWord(HiddenWord w) {
    showWordSheet(context, word: w.word.toLowerCase(), language: _language);
  }

  bool get _solved => _puzzle != null && _found.length == _puzzle!.words.length;

  // ── Dragging ──────────────────────────────────────────────────────────────

  (int, int) _cellAt(Offset p, double cell) {
    final size = _puzzle!.size;
    return (
      (p.dy / cell).floor().clamp(0, size - 1),
      (p.dx / cell).floor().clamp(0, size - 1),
    );
  }

  /// The end of a straight line from [start] towards [to]: snapped to the
  /// nearest of the eight directions and kept inside the grid.
  (int, int) _snap((int, int) start, (int, int) to) {
    final (r0, c0) = start;
    final dr = to.$1 - r0, dc = to.$2 - c0;
    if (dr == 0 && dc == 0) return start;
    final step = (atan2(dr.toDouble(), dc.toDouble()) / (pi / 4)).round();
    final angle = step * pi / 4;
    final sr = sin(angle).round(), sc = cos(angle).round();
    var n = max(dr.abs(), dc.abs());
    final size = _puzzle!.size;
    while (n > 0) {
      final r = r0 + sr * n, c = c0 + sc * n;
      if (r >= 0 && r < size && c >= 0 && c < size) return (r, c);
      n--;
    }
    return start;
  }

  void _dragBegin(Offset p, double cell) {
    if (_solved) return;
    final c = _cellAt(p, cell);
    setState(() => _dragStart = _dragEnd = c);
  }

  void _dragMove(Offset p, double cell) {
    final start = _dragStart;
    if (start == null) return;
    final end = _snap(start, _cellAt(p, cell));
    if (end != _dragEnd) setState(() => _dragEnd = end);
  }

  void _dragDone() {
    final start = _dragStart, end = _dragEnd;
    setState(() => _dragStart = _dragEnd = null);
    if (start == null || end == null || start == end) return;
    final word = _puzzle!.wordAt(start.$1, start.$2, end.$1, end.$2);
    if (word == null || _found.containsKey(word.word)) return;
    setState(() => _found[word.word] = _found.length % wordSearchTints.length);
    _save();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
    final clay = brightness.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final card = brightness.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final puzzle = _puzzle;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: level on the left, Home on the right ────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.md,
                Spacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: DualText(
                          (t) => t.level(_level),
                          style: kickerStyle(brightness: brightness),
                        ),
                      ),
                    ),
                  ),
                  const HomeButton(),
                ],
              ),
            ),
            Expanded(
              child: puzzle == null
                  ? _buildStatus(muted: muted, clay: clay)
                  : SingleChildScrollView(
                      physics: _touchingGrid
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGrid(
                            puzzle,
                            ink: ink,
                            clay: clay,
                            card: card,
                            hairline: hairline,
                            brightness: brightness,
                          ),
                          const SizedBox(height: Spacing.md),
                          if (_solved) ...[
                            _buildSolved(clay: clay),
                            const SizedBox(height: Spacing.md),
                          ],
                          _buildWordList(
                            puzzle,
                            ink: ink,
                            muted: muted,
                            card: card,
                            hairline: hairline,
                            brightness: brightness,
                          ),
                          // ── TEST ONLY: skip to the next level unsolved ──
                          // TODO: remove before publishing.
                          if (!_solved) ...[
                            const SizedBox(height: Spacing.lg),
                            GestureDetector(
                              key: const Key('ws-next-level-test'),
                              onTap: () => _startLevel(_level + 1),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                    Radius.sm,
                                  ),
                                  border: Border.all(
                                    color: hairline,
                                    width: 0.5,
                                  ),
                                ),
                                child: Center(
                                  child: DualText(
                                    (t) => t.nextLevelTest,
                                    inline: true,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: ink,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  Widget _buildStatus({required Color muted, required Color clay}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_loadFailed) const CircularProgressIndicator(),
          const SizedBox(height: Spacing.md),
          DualText(
            (t) => _loadFailed ? t.couldNotSetPuzzle : t.settingLevel(_level),
            crossAxisAlignment: CrossAxisAlignment.center,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: muted, fontFamily: 'Inter'),
          ),
          if (_loadFailed) ...[
            const SizedBox(height: Spacing.md),
            TextButton(
              onPressed: () => _startLevel(_level),
              child: DualText(
                (t) => t.tryAgain,
                crossAxisAlignment: CrossAxisAlignment.center,
                style: TextStyle(color: clay),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid(
    WordSearchPuzzle puzzle, {
    required Color ink,
    required Color clay,
    required Color card,
    required Color hairline,
    required Brightness brightness,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Square grid as wide as the page (inside a 6-point frame).
        final side = constraints.maxWidth - 12;
        final cell = side / puzzle.size;
        final dark = brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(Radius.sm),
            border: Border.all(color: hairline, width: 0.5),
          ),
          child: Listener(
            onPointerDown: (_) => _setTouching(true),
            onPointerUp: (_) => _setTouching(false),
            onPointerCancel: (_) => _setTouching(false),
            child: GestureDetector(
              key: const Key('ws-grid'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _dragBegin(d.localPosition, cell),
              onPanUpdate: (d) => _dragMove(d.localPosition, cell),
              onPanEnd: (_) => _dragDone(),
              onPanCancel: _dragDone,
              child: CustomPaint(
                size: Size.square(side),
                painter: _GridPainter(
                  puzzle: puzzle,
                  found: {
                    for (final w in puzzle.words)
                      if (_found[w.word] case final tint?)
                        // A little see-through, so where two found words
                        // cross, the tints blend like highlighter ink.
                        w: wordSearchTints[tint].withValues(
                          alpha: dark ? 0.5 : 0.75,
                        ),
                  },
                  drag: _dragStart != null && _dragEnd != null
                      ? (_dragStart!, _dragEnd!)
                      : null,
                  dragColor: clay.withValues(alpha: 0.35),
                  ink: ink,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _setTouching(bool on) {
    if (_touchingGrid != on) setState(() => _touchingGrid = on);
  }

  Widget _buildSolved({required Color clay}) {
    return Container(
      key: const Key('ws-solved'),
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: clay,
        borderRadius: BorderRadius.circular(Radius.sm),
      ),
      child: Column(
        children: [
          DualText(
            (t) => t.allWordsFound,
            crossAxisAlignment: CrossAxisAlignment.center,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            secondaryStyle: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: Spacing.sm),
          FilledButton(
            key: const Key('ws-next-level'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: clay,
            ),
            onPressed: () => _startLevel(_level + 1),
            child: DualText(
              (t) => t.nextLevel,
              inline: true,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: clay,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(
    WordSearchPuzzle puzzle, {
    required Color ink,
    required Color muted,
    required Color card,
    required Color hairline,
    required Brightness brightness,
  }) {
    final dark = brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DualText(
                (t) => t.wordsToFind,
                inline: true,
                style: kickerStyle(brightness: brightness),
              ),
            ),
            DualText(
              (t) => t.foundCount(_found.length, puzzle.words.length),
              crossAxisAlignment: CrossAxisAlignment.end,
              style: TextStyle(fontSize: 12, color: muted, fontFamily: 'Inter'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        if (_found.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: DualText(
              (t) => t.dragToFind,
              style: TextStyle(fontSize: 13, color: muted, fontFamily: 'Inter'),
            ),
          ),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final w in puzzle.words)
              _wordChip(
                w,
                tint: _found[w.word],
                ink: ink,
                muted: muted,
                card: card,
                hairline: hairline,
                dark: dark,
              ),
          ],
        ),
      ],
    );
  }

  /// The word in the secondary language, under its chip, when the
  /// secondary language is the other one (English ↔ Greek) and it's known.
  Widget _wordTranslation(HiddenWord w) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final other = _language == 'el' ? 'en' : 'el';
        final text = w.wordTr;
        if (text == null || AppSettings.instance.secondaryLanguage != other) {
          return const SizedBox.shrink();
        }
        return Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: translationColor(context),
            fontFamily: 'Inter',
          ),
        );
      },
    );
  }

  Widget _wordChip(
    HiddenWord w, {
    required int? tint,
    required Color ink,
    required Color muted,
    required Color card,
    required Color hairline,
    required bool dark,
  }) {
    final found = tint != null;
    // A found word opens its word page.
    return GestureDetector(
      onTap: found ? () => _openWord(w) : null,
      child: Container(
        key: Key('ws-word-${w.word}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: found
              ? wordSearchTints[tint].withValues(alpha: dark ? 0.55 : 1)
              : card,
          borderRadius: BorderRadius.circular(Radius.sm),
          border: Border.all(color: found ? Colors.transparent : hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              w.word,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                fontFamily: 'Inter',
                color: ink,
              ),
            ),
            _wordTranslation(w),
          ],
        ),
      ),
    );
  }
}

/// Draws the found-word highlights, the line being dragged, and the letters.
class _GridPainter extends CustomPainter {
  final WordSearchPuzzle puzzle;
  final Map<HiddenWord, Color> found;
  final ((int, int), (int, int))? drag;
  final Color dragColor;
  final Color ink;

  _GridPainter({
    required this.puzzle,
    required this.found,
    required this.drag,
    required this.dragColor,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / puzzle.size;
    Offset centre((int, int) rc) =>
        Offset((rc.$2 + 0.5) * cell, (rc.$1 + 0.5) * cell);

    // Highlighter strokes: rounded bands from first to last letter.
    void band((int, int) a, (int, int) b, Color color) {
      canvas.drawLine(
        centre(a),
        centre(b),
        Paint()
          ..color = color
          ..strokeWidth = cell * 0.78
          ..strokeCap = StrokeCap.round,
      );
    }

    for (final MapEntry(key: w, value: color) in found.entries) {
      band(w.cells.first, w.cells.last, color);
    }
    if (drag case (final a, final b)) band(a, b, dragColor);

    // Letters (a fixed size for the square: the phone's text size doesn't
    // apply, so they always fit).
    for (var r = 0; r < puzzle.size; r++) {
      for (var c = 0; c < puzzle.size; c++) {
        final tp = TextPainter(
          text: TextSpan(
            text: puzzle.letterAt(r, c),
            style: TextStyle(
              fontSize: cell * 0.52,
              fontWeight: FontWeight.w600,
              color: ink,
              fontFamily: 'Inter',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, centre((r, c)) - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.puzzle != puzzle ||
      old.found.length != found.length ||
      old.drag != drag ||
      old.ink != ink;
}
