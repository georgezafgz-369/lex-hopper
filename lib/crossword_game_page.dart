// ─────────────────────────────────────────────────────────────────────────────
// CROSSWORD GAME PAGE — the puzzle grid, clues, and action buttons
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'dual_text.dart';
import 'design_system.dart';
import 'crossword_maker.dart';
import 'crossword_puzzle.dart';
import 'crossword_save.dart';
import 'puzzle_themes.dart';
import 'dictionary_page.dart';
import 'word_look_up.dart';
import 'word_sheet.dart' show showWordSheet;

// ──────────────────────────────────────────────────────────────────────────────
// GAME PAGE
// ──────────────────────────────────────────────────────────────────────────────

enum _ClueDirection { across, down }

class CrosswordGamePage extends StatefulWidget {
  final int startLevel;
  final Map<String, dynamic>? resumeState; // null = new game, map = continue

  /// Play this puzzle instead of generating one (used by tests).
  final CrosswordPuzzle? puzzle;

  /// "en" or "el": the language of the answers and clues. A game keeps the
  /// language it started in (a resumed game: the one it was saved in).
  final String language;

  /// The subject chosen at New Game (null: all subjects). A resumed game
  /// takes the one it was saved with.
  final PuzzleTheme? theme;

  const CrosswordGamePage({
    super.key,
    this.startLevel = 1,
    this.resumeState,
    this.puzzle,
    this.language = 'en',
    this.theme,
  });

  @override
  State<CrosswordGamePage> createState() => _CrosswordGamePageState();
}

class _CrosswordGamePageState extends State<CrosswordGamePage> {
  late int _currentLevel;

  /// Null while a new puzzle is being generated.
  CrosswordPuzzle? _loadedPuzzle;
  CrosswordPuzzle get _puzzle => _loadedPuzzle!;
  bool _loadFailed = false;

  // User input: keyed by "row,col"
  final Map<String, String> _userLetters = {};

  // Cell states: keyed by "row,col"
  final Map<String, String> _cellStates = {}; // 'correct', 'wrong', ''

  _ClueDirection _direction = _ClueDirection.across;
  String? _selectedCellKey;
  Clue? _selectedClue; // set when user taps a clue in the list

  /// The game's language ("en" or "el").
  /// This game's subject: the one saved with it, or the one chosen.
  late final PuzzleTheme? _theme = widget.resumeState != null
      ? PuzzleTheme.byId(widget.resumeState!['theme'] as String?)
      : widget.theme;

  late final String _language =
      (widget.resumeState?['language'] as String?) ?? widget.language;
  bool get _greek => _language == 'el';

  @override
  void initState() {
    super.initState();
    _currentLevel = widget.startLevel;

    final saved = widget.resumeState;
    final savedPuzzle = saved?['puzzle'];
    if (widget.puzzle != null) {
      _loadedPuzzle = widget.puzzle;
    } else if (saved != null && savedPuzzle != null) {
      // Resume from saved state
      _loadedPuzzle = CrosswordPuzzle.fromJson(
        Map<String, dynamic>.from(savedPuzzle),
      );
      _userLetters.addAll(Map<String, String>.from(saved['userLetters'] ?? {}));
      _cellStates.addAll(Map<String, String>.from(saved['cellStates'] ?? {}));
      _selectedCellKey = saved['selectedCellKey'];
      // A wrong word saved before its letters were erased (the app closed
      // within the 2 seconds) is erased now.
      _cellStates.updateAll((k, state) {
        if (state != 'wrong') return state;
        _userLetters[k] = '';
        return '';
      });
      // A save that is already fully correct opens as solved.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkIfSolved();
      });
    } else {
      // New game (or a save from before puzzles were generated).
      _startLevel(_currentLevel);
    }
  }

  // ── Save / Load ───────────────────────────────────────────────────────────

  Future<void> _saveState() async {
    final state = {
      'currentLevel': _currentLevel,
      'userLetters': Map<String, String>.from(_userLetters),
      'cellStates': Map<String, String>.from(_cellStates),
      'selectedCellKey': _selectedCellKey,
      'puzzle': _puzzle.toJson(),
      'language': _language,
      if (_theme != null) 'theme': _theme.id,
    };
    await CrosswordSave.save(state, language: _language);
  }

  /// Generate a fresh puzzle for [level] from the dictionary and start it.
  Future<void> _startLevel(int level) async {
    setState(() {
      _currentLevel = level;
      _loadedPuzzle = null;
      _loadFailed = false;
      _cancelEraseTimers();
      _userLetters.clear();
      _cellStates.clear();
      _selectedCellKey = null;
      _selectedClue = null;
      _direction = _ClueDirection.across;
      _gridView.value = Matrix4.identity();
      _revealedCellKey = null;
    });
    try {
      final puzzle = await CrosswordMaker.make(
        level,
        language: _language,
        theme: _theme,
      );
      if (!mounted) return;
      setState(() => _loadedPuzzle = puzzle);
      _saveState();
    } catch (e) {
      debugPrint('Crossword generation failed: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// True when every answer has been checked correct.
  /// True when every cell holds the right letter (typed or hinted),
  /// whether or not the player pressed Check.
  bool get _isSolved => _puzzle.grid
      .where((c) => !c.isBlack)
      .every((c) => _userLetters[_key(c.row, c.col)] == c.answer);

  /// Call after any letter changes. Once the whole grid is right, mark every
  /// cell correct, close the keyboard, and let "Next level" appear.
  void _checkIfSolved() {
    if (!_isSolved) return;
    setState(() {
      for (final c in _puzzle.grid.where((c) => !c.isBlack)) {
        _cellStates[_key(c.row, c.col)] = 'correct';
      }
    });
    _inputFocus.unfocus();
    _saveState();
  }

  /// "Next level" button: fresh puzzle one level up.
  void _goToNextLevel() {
    _inputFocus.unfocus();
    _startLevel(_currentLevel + 1);
  }

  String _key(int r, int c) => '$r,$c';

  GridCell? _cell(int r, int c) => _puzzle.cellAt(r, c);

  // ── Keyboard input ──────────────────────────────────────────────────────
  //
  // A hidden TextField receives both the on-screen keyboard (mobile) and a
  // hardware keyboard (desktop/web). It always holds one invisible sentinel
  // character so a backspace on an "empty" field can still be detected.

  /// Smallest square size. A grid that would need smaller squares to fit
  /// the screen keeps this size instead and sits in a window that can be
  /// dragged around and pinch-zoomed, like a map.
  static const _minCellSize = 40.0;
  final _gridView = TransformationController();

  /// The page's own scrolling (grid, clues, buttons).
  final _pageScroll = ScrollController();
  // Height of the floating Back / level bar over the page.
  static const _topBarHeight = Spacing.sm + 40 + Spacing.sm;
  // The floating Clear | Hint | Check pill, to scroll it into view.
  final _wordToolsKey = GlobalKey();
  final _gridKey = GlobalKey();
  Timer? _clearScroll;

  /// Set while the grid is in its draggable window: the square size and
  /// the window size, used to keep the selected square in view.
  double? _panCellSize;
  Size? _panViewport;
  String? _revealedCellKey;

  /// True while a finger is on the draggable grid: the page itself then
  /// doesn't scroll, so the drag moves the grid (like a map).
  bool _touchingGrid = false;

  static const _sentinel = '​';
  final _inputController = TextEditingController(text: _sentinel);
  final _inputFocus = FocusNode();
  static final _latinLetter = RegExp(r'[A-Za-z]');
  // Greek letters, with or without accents (ά is typed as one letter).
  static final _greekLetter = RegExp(r'[Α-ΩΆ-Ώα-ωά-ώϊϋΐΰΪΫς]');

  /// How long a wrong word shows its ✕ marks before it is erased.
  static const wrongWordDelay = Duration(seconds: 2);

  /// Timers that erase wrong words (cancelled on a new puzzle or on leaving).
  final List<Timer> _eraseTimers = [];

  void _cancelEraseTimers() {
    for (final t in _eraseTimers) {
      t.cancel();
    }
    _eraseTimers.clear();
  }

  @override
  void dispose() {
    _cancelEraseTimers();
    _gridView.dispose();
    _clearScroll?.cancel();
    _pageScroll.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _resetInput() {
    _inputController.value = const TextEditingValue(
      text: _sentinel,
      selection: TextSelection.collapsed(offset: _sentinel.length),
    );
  }

  void _onInputChanged(String value) {
    if (value.isEmpty) {
      _backspace();
    } else {
      for (final ch in value.replaceAll(_sentinel, '').split('')) {
        if (_greek) {
          // Greek answers are capitals without accents: ά -> Α, ς -> Σ.
          if (_greekLetter.hasMatch(ch)) _typeLetter(AppText.upper(ch));
        } else if (_latinLetter.hasMatch(ch)) {
          _typeLetter(ch.toUpperCase());
        }
      }
    }
    _resetInput();
  }

  void _typeLetter(String letter) {
    final k = _selectedCellKey;
    if (k == null) return;
    setState(() {
      _userLetters[k] = letter;
      _cellStates[k] = ''; // clear previous check state
    });
    _moveWithinWord(1);
    _saveState();
    _checkIfSolved();
  }

  void _backspace() {
    final k = _selectedCellKey;
    if (k == null) return;
    // If the current cell is already empty, step back first, then clear.
    if ((_userLetters[k] ?? '').isEmpty) _moveWithinWord(-1);
    final target = _selectedCellKey!;
    setState(() {
      _userLetters[target] = '';
      _cellStates[target] = '';
    });
    _saveState();
  }

  /// Move the cursor one cell forward/back inside the active word.
  void _moveWithinWord(int delta) {
    final clue = _activeClue();
    final k = _selectedCellKey;
    if (clue == null || k == null) return;
    final cells = clue.cells.where((c) => !c.isBlack).toList();
    final i = cells.indexWhere((c) => _key(c.row, c.col) == k);
    final next = i + delta;
    if (i < 0 || next < 0 || next >= cells.length) return;
    setState(() {
      _selectedCellKey = _key(cells[next].row, cells[next].col);
    });
  }

  /// The clue in direction [dir] that contains the cell at [r],[c].
  Clue? _clueFor(int r, int c, _ClueDirection dir) {
    final list = dir == _ClueDirection.across ? _puzzle.across : _puzzle.down;
    for (final clue in list) {
      if (clue.cells.any((cell) => cell.row == r && cell.col == c)) return clue;
    }
    return null;
  }

  void _selectCell(int r, int c) {
    final k = _key(r, c);
    final other = _direction == _ClueDirection.across
        ? _ClueDirection.down
        : _ClueDirection.across;
    setState(() {
      // Tapping the selected cell again flips direction (if a word runs that way).
      // Tapping a cell with no word in the current direction switches to the other.
      final flip =
          (k == _selectedCellKey && _clueFor(r, c, other) != null) ||
          _clueFor(r, c, _direction) == null;
      if (flip) _direction = other;
      _selectedCellKey = k;
      _selectedClue = _clueFor(r, c, _direction);
    });
    _focusInput();
  }

  // Last clue tap, to spot a double tap without delaying single taps.
  Clue? _lastClueTap;
  DateTime _lastClueTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Called when the user taps a clue in the clue list.
  /// A single tap highlights the clue's cells and selects its first cell,
  /// and closes the keyboard if it's open. Only a double tap opens the
  /// keyboard to type the word, and scrolls back up to the grid so its
  /// squares are in view. Tapping a grid cell always opens it.
  void _selectClue(Clue clue) {
    final now = DateTime.now();
    final isDoubleTap =
        _lastClueTap == clue &&
        now.difference(_lastClueTapTime) < const Duration(milliseconds: 400);
    _lastClueTap = clue;
    _lastClueTapTime = now;

    setState(() {
      _selectedClue = clue;
      final first = clue.cells.firstWhere((cell) => !cell.isBlack);
      _selectedCellKey = _key(first.row, first.col);
    });
    // In a big grid, bring the whole word into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealWord(clue);
      // Then scroll the page so Clear | Hint | Check isn't left under the
      // top bar (when the clues were scrolled up past the grid).
      if (!isDoubleTap) {
        // Once a second tap can no longer come (the page mustn't move under
        // a double tap on a word), and after the grid has moved.
        _clearScroll?.cancel();
        _clearScroll = Timer(const Duration(milliseconds: 350), () async {
          await WidgetsBinding.instance.endOfFrame;
          // Not if a second tap has since made it a double tap.
          if (!mounted || _lastClueTapTime != now) return;
          _scrollClearOfTopBar(clue);
        });
      }
    });
    // A double tap on a word opens it in the dictionary instead.
    if (isDoubleTap && !WordLookUp.justLookedUp) {
      _focusInput();
      if (_pageScroll.hasClients && _pageScroll.offset > 0) {
        _pageScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      // A single tap only selects the word: the keyboard goes away so the
      // clues stay readable.
      _inputFocus.unfocus();
    }
  }

  /// Scroll the page up just enough that the Clear | Hint | Check pill
  /// isn't hidden under the floating top bar, nor [clue]'s word when the
  /// pill sits below it (a word on the top row).
  void _scrollClearOfTopBar(Clue clue) {
    final onTopRow = clue.cells.any((c) => c.row == 0);
    final target = (onTopRow ? _gridKey : _wordToolsKey).currentContext;
    final box = target?.findRenderObject() as RenderBox?;
    if (box == null || !_pageScroll.hasClients) return;
    final page =
        _pageScroll.position.context.notificationContext?.findRenderObject()
            as RenderBox?;
    if (page == null) return;
    final top = box.localToGlobal(Offset.zero, ancestor: page).dy;
    const room = _topBarHeight + Spacing.xs;
    if (top >= room) return;
    _pageScroll.animateTo(
      max(0.0, _pageScroll.offset - (room - top)),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _focusInput() {
    _resetInput();
    _inputFocus.requestFocus();
    // Re-show the soft keyboard if it was dismissed while focus stayed put.
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Return the clue (and its cells) that the currently selected cell belongs to.
  Clue? _currentClue() {
    if (_selectedCellKey == null) return null;
    final parts = _selectedCellKey!.split(',');
    final r = int.parse(parts[0]);
    final c = int.parse(parts[1]);

    final candidates = _direction == _ClueDirection.across
        ? _puzzle.across
        : _puzzle.down;

    for (final clue in candidates) {
      if (clue.cells.any((cell) => cell.row == r && cell.col == c)) {
        return clue;
      }
    }
    return null;
  }

  /// The word being worked on: the highlighted one (tapped in the grid or
  /// the clue list), else the one under the cursor. Check, Clear, Hint and
  /// the buttons over the word all act on this word.
  Clue? _activeClue() => _selectedClue ?? _currentClue();

  // ── Actions ─────────────────────────────────────────────────────────────

  /// Check the selected word as a whole: every cell turns correct if the
  /// full word is right, otherwise every cell turns wrong. Individual
  /// letters are never revealed. An unfinished word is not judged at all.
  void _checkSelectedWord() {
    final clue = _activeClue();
    if (clue == null) return;

    final cells = clue.cells
        .where((c) => !c.isBlack && c.answer != null)
        .toList();
    final isComplete = cells.every(
      (c) => (_userLetters[_key(c.row, c.col)] ?? '').isNotEmpty,
    );
    if (!isComplete) return;

    final isCorrect = cells.every(
      (c) => _userLetters[_key(c.row, c.col)] == c.answer,
    );

    // Letters of a crossing word already solved: they are right, so a wrong
    // word only marks them for a moment and never erases them. That covers
    // a green cell, and also one retyped (with the right letter) after its
    // crossing word went green, which no longer shows green itself.
    final keep = {
      for (final c in cells)
        if (_cellStates[_key(c.row, c.col)] == 'correct' ||
            _solvedAcross(clue, c))
          _key(c.row, c.col),
    };

    setState(() {
      for (final cell in cells) {
        _cellStates[_key(cell.row, cell.col)] = isCorrect ? 'correct' : 'wrong';
      }
    });
    _saveState();
    _checkIfSolved();
    if (!isCorrect) _eraseWrongWordLater(cells, keep);
  }

  /// Whether [cell] of [clue] holds its right letter and the word crossing
  /// it there is otherwise all green (solved).
  bool _solvedAcross(Clue clue, GridCell cell) {
    if (_userLetters[_key(cell.row, cell.col)] != cell.answer) return false;
    final inAcross = _puzzle.across.contains(clue);
    final crossing = _clueFor(
      cell.row,
      cell.col,
      inAcross ? _ClueDirection.down : _ClueDirection.across,
    );
    if (crossing == null) return false;
    return crossing.cells
        .where((c) => !c.isBlack && c.answer != null)
        .where((c) => c.row != cell.row || c.col != cell.col)
        .every((c) => _cellStates[_key(c.row, c.col)] == 'correct');
  }

  /// A wrong word shows its ✕ marks for [wrongWordDelay], then its letters
  /// are erased so it can be typed again. Cells in [keep] (right, from a
  /// crossing word) keep their letter and turn green again; cells the player
  /// has already retyped meanwhile are left alone.
  void _eraseWrongWordLater(List<GridCell> cells, Set<String> keep) {
    late final Timer timer;
    timer = Timer(wrongWordDelay, () {
      _eraseTimers.remove(timer);
      if (!mounted) return;
      setState(() {
        String? firstErased;
        for (final cell in cells) {
          final k = _key(cell.row, cell.col);
          if (_cellStates[k] != 'wrong') continue; // retyped meanwhile
          if (keep.contains(k)) {
            _cellStates[k] = 'correct';
          } else {
            _userLetters[k] = '';
            _cellStates[k] = '';
            firstErased ??= k;
          }
        }
        // Still on this word: the cursor goes back to its first emptied
        // square, ready to type the word again.
        final onWord = cells.any((c) => _key(c.row, c.col) == _selectedCellKey);
        if (onWord && firstErased != null) _selectedCellKey = firstErased;
      });
      _saveState();
    });
    _eraseTimers.add(timer);
  }

  /// The answer to [clue] once it has been confirmed correct (every cell
  /// green, by Check or by solving the whole puzzle), otherwise null.
  String? _confirmedAnswer(Clue clue) {
    final cells = clue.cells.where((c) => !c.isBlack && c.answer != null);
    if (cells.isEmpty) return null;
    final confirmed = cells.every(
      (c) => _cellStates[_key(c.row, c.col)] == 'correct',
    );
    if (!confirmed) return null;
    // Phrases keep their spaces: "GIVE UP".
    return clue.cells.map((c) => c.isGap ? ' ' : (c.answer ?? '')).join();
  }

  /// Open the word page for a solved answer, e.g. "SEARCH".
  void _openAnswer(String answer) {
    _inputFocus.unfocus();
    // In the game's dictionary (it finds σπίτι from ΣΠΙΤΙ).
    showWordSheet(context, word: answer.toLowerCase(), language: _language);
  }

  /// Reveal the first unrevealed letter of the selected word.
  void _revealHint() {
    final clue = _activeClue();
    if (clue == null) return;

    for (final cell in clue.cells) {
      if (cell.isBlack || cell.answer == null) continue;
      final k = _key(cell.row, cell.col);
      // Skip cells that are already filled correctly
      if (_userLetters[k] == cell.answer) continue;
      // Reveal this cell (no state flag — just the letter, no checkmark)
      setState(() {
        _userLetters[k] = cell.answer!;
      });
      _saveState();
      _checkIfSolved();
      return;
    }
  }

  /// Clear only the currently selected word. Letters of a crossing word
  /// already solved stay; the cursor goes to the word's first emptied
  /// square.
  void _clearSelectedWord() {
    final clue = _activeClue();
    if (clue == null) return;

    setState(() {
      String? firstErased;
      for (final cell in clue.cells) {
        if (cell.isBlack || cell.isGap || cell.answer == null) continue;
        final k = _key(cell.row, cell.col);
        if (_cellStates[k] == 'correct' || _solvedAcross(clue, cell)) {
          if (_userLetters[k] == cell.answer) _cellStates[k] = 'correct';
          continue;
        }
        _userLetters[k] = '';
        _cellStates[k] = '';
        firstErased ??= k;
      }
      if (firstErased != null) _selectedCellKey = firstErased;
    });
    _saveState();
  }

  /// Open the dictionary sheet, searching for what the player has typed in
  /// the selected word so far. Empty cells become "_" (a one-letter wildcard),
  /// so "AP_LE" finds "apple". Never uses the answer itself.
  void _openDictionary() {
    final clue = _activeClue();
    var query = '';
    if (clue != null) {
      query = clue.cells
          .where((cell) => !cell.isBlack || cell.isGap)
          .map((cell) {
            if (cell.isGap) return ' '; // phrase: "give u_"
            final letter = _userLetters[_key(cell.row, cell.col)] ?? '';
            return letter.isEmpty ? '_' : letter;
          })
          .join()
          .replaceFirst(RegExp(r'_+$'), '')
          .toLowerCase();
      if (query.replaceAll('_', '').isEmpty) query = '';
    }
    _inputFocus.unfocus();
    showDictionarySheet(context, initialQuery: query);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final paper = brightness.resolve(
      light: AppColors.paperLight,
      dark: AppColors.paperDark,
    );
    final gridCell = brightness.resolve(
      light: AppColors.gridCellLight,
      dark: AppColors.gridCellDark,
    );
    final crosswordCell = brightness.resolve(
      light: AppColors.crosswordCellLight,
      dark: AppColors.crosswordCellDark,
    );
    final crosswordCellBorder = brightness.resolve(
      light: AppColors.crosswordCellBorderLight,
      dark: AppColors.crosswordCellBorderDark,
    );
    final hairline = brightness.resolve(
      light: AppColors.hairlineLight,
      dark: AppColors.hairlineDark,
    );
    final clay = brightness.resolve(
      light: AppColors.clayLight,
      dark: AppColors.clayDark,
    );
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final correct = brightness.resolve(
      light: AppColors.checkedCorrectLight,
      dark: AppColors.checkedCorrectDark,
    );
    final wrong = brightness.resolve(
      light: AppColors.checkedWrongLight,
      dark: AppColors.checkedWrongDark,
    );
    final selected = brightness.resolve(
      light: AppColors.selectedCellLight,
      dark: AppColors.selectedCellDark,
    );
    final currentWord = brightness.resolve(
      light: AppColors.currentWordLight,
      dark: AppColors.currentWordDark,
    );

    if (_loadedPuzzle == null) {
      return _buildStatusPage(brightness: brightness, paper: paper, clay: clay);
    }

    final clues = _direction == _ClueDirection.across
        ? _puzzle.across
        : _puzzle.down;

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
            // Hidden input that captures typing (see "Keyboard input").
            SizedBox(
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocus,
                  onChanged: _onInputChanged,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: false,
                  showCursor: false,
                  // The password keyboard has no suggestions, but on many
                  // phones only Latin letters; Greek uses the text one.
                  keyboardType: _greek
                      ? TextInputType.text
                      : TextInputType.visiblePassword,
                  textCapitalization: TextCapitalization.characters,
                  // The keyboard's ✓ key checks the word, like Check, and
                  // keeps the keyboard open for the next word.
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _checkSelectedWord,
                  decoration: const InputDecoration.collapsed(hintText: ''),
                ),
              ),
            ),

            // ── Grid ──────────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    key: const Key('crossword-page-scroll'),
                    controller: _pageScroll,
                    physics: _touchingGrid
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    // Room at the top for the floating bar, and a little more.
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.md,
                      _topBarHeight + Spacing.sm,
                      Spacing.md,
                      0,
                    ),
                    child: Column(
                      children: [
                        KeyedSubtree(
                          key: _gridKey,
                          child: _buildGrid(
                            crosswordCellBorder: crosswordCellBorder,
                            crosswordCell: crosswordCell,
                            ink: ink,
                            correct: correct,
                            wrong: wrong,
                            selected: selected,
                            currentWord: currentWord,
                          ),
                        ),
                        const SizedBox(height: Spacing.md),

                        // ── Clue list ─────────────────────────────────────────
                        _buildClueList(
                          clues: clues,
                          brightness: brightness,
                          gridCell: gridCell,
                          hairline: hairline,
                          clay: clay,
                          selected: selected,
                        ),
                        const SizedBox(height: Spacing.md),

                        // ── TEST ONLY: skip to the next level unsolved ──────
                        // TODO: remove before publishing.
                        if (!_isSolved) ...[
                          const SizedBox(height: Spacing.sm),
                          _actionButton(
                            label: (t) => t.nextLevelTest,
                            bg: Colors.transparent,
                            fg: ink,
                            borderColor: hairline,
                            onTap: _goToNextLevel,
                          ),
                        ],
                        const SizedBox(height: Spacing.xxl),
                      ],
                    ),
                  ),
                  // ── Floating top bar: Back and the level hover over
                  // the page, which scrolls under them.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.md,
                        Spacing.sm,
                        Spacing.md,
                        Spacing.sm,
                      ),
                      child: Row(
                        children: [
                          Material(
                            color: gridCell,
                            elevation: 3,
                            shadowColor: Colors.black38,
                            borderRadius: BorderRadius.circular(Radius.sm),
                            child: InkWell(
                              key: const Key('crossword-back'),
                              borderRadius: BorderRadius.circular(Radius.sm),
                              onTap: () => Navigator.of(context).maybePop(),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  Icons.arrow_back,
                                  size: 20,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: Spacing.sm),
                          Expanded(
                            child: Center(
                              child: Material(
                                color: gridCell,
                                elevation: 3,
                                shadowColor: Colors.black38,
                                borderRadius: BorderRadius.circular(Radius.sm),
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.md,
                                  ),

                                  child: Center(
                                    widthFactor: 1,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: DualText(
                                        (t) => t.level(_currentLevel),
                                        style: kickerStyle(
                                          brightness: brightness,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Balances the Back button, keeping the level
                          // centred.
                          const SizedBox(width: 40 + Spacing.sm),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Next level (only once every word is checked correct) ───────
            if (_isSolved)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.md,
                  Spacing.sm,
                  Spacing.md,
                  Spacing.md,
                ),
                child: _actionButton(
                  label: (t) => t.nextLevel,
                  bg: clay,
                  fg: Colors.white,
                  borderColor: clay,
                  onTap: _goToNextLevel,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Loading / error ───────────────────────────────────────────────────────

  Widget _buildStatusPage({
    required Brightness brightness,
    required Color paper,
    required Color clay,
  }) {
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    String message(AppText t) =>
        _loadFailed ? t.couldNotSetPuzzle : t.settingLevel(_currentLevel);

    return Scaffold(
      backgroundColor: paper,
      body: SafeArea(
        child: Column(
          children: [
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
                  DualText(
                    (t) => t.level(_currentLevel),
                    style: kickerStyle(brightness: brightness),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_loadFailed) const CircularProgressIndicator(),
                    const SizedBox(height: Spacing.md),
                    DualText(
                      message,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: muted,
                        fontFamily: 'Inter',
                      ),
                    ),
                    if (_loadFailed) ...[
                      const SizedBox(height: Spacing.md),
                      TextButton(
                        onPressed: () => _startLevel(_currentLevel),
                        child: DualText(
                          (t) => t.tryAgain,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          style: TextStyle(color: clay),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────

  Widget _buildGrid({
    required Color crosswordCell,
    required Color crosswordCellBorder,
    required Color ink,
    required Color correct,
    required Color wrong,
    required Color selected,
    required Color currentWord,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate cell size based on available width
        // Subtract: container padding (2*2) + cell gaps (1*(cols-1))
        final availableWidth = constraints.maxWidth - 4 - (_puzzle.cols - 1);
        final fitSize = (availableWidth / _puzzle.cols).truncateToDouble();
        final pan = fitSize < _minCellSize;
        final cellSize = pan ? _minCellSize : fitSize;

        // Grid letters and numbers keep their size whatever the Settings
        // font size, so they always fit their squares.
        final grid = MediaQuery.withNoTextScaling(
          child: NoWordLookUp(
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_puzzle.rows, (r) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_puzzle.cols, (c) {
                          final cell = _cell(r, c);
                          if (cell != null && cell.isGap) {
                            // The space inside a phrase: a solid ink square, the
                            // same size and inset as a letter cell.
                            return Container(
                              key: Key('gap-$r-$c'),
                              width: cellSize,
                              height: cellSize,
                              padding: const EdgeInsets.all(1),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: ink,
                                  border: Border.all(
                                    color: crosswordCellBorder,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            );
                          }
                          if (cell == null || cell.isBlack) {
                            return SizedBox(width: cellSize, height: cellSize);
                          }

                          final k = _key(r, c);
                          final letter = _userLetters[k] ?? '';
                          final state = _cellStates[k] ?? '';
                          final isSelected = k == _selectedCellKey;
                          // Check if this cell belongs to the selected clue
                          final isClueCell =
                              _selectedClue != null &&
                              _selectedClue!.cells.any(
                                (cc) => cc.row == r && cc.col == c,
                              );

                          Color bgColor = crosswordCell;
                          if (state == 'correct') {
                            bgColor = correct;
                          } else if (state == 'wrong') {
                            bgColor = wrong;
                          } else if (isSelected) {
                            bgColor = selected;
                          } else if (isClueCell) {
                            bgColor = currentWord;
                          }

                          return GestureDetector(
                            onTap: () => _selectCell(r, c),
                            child: Container(
                              width: cellSize,
                              height: cellSize,
                              padding: const EdgeInsets.all(1),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      border: Border.all(
                                        color: crosswordCellBorder,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                  // Clue number
                                  if (cell.clueNumber != null)
                                    Positioned(
                                      top: 2,
                                      left: 3,
                                      child: Text(
                                        '${cell.clueNumber}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: ink.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  // User letter
                                  if (letter.isNotEmpty)
                                    Center(
                                      child: Text(
                                        letter,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                    ),
                                  // Status icon
                                  if (state == 'correct')
                                    Positioned(
                                      bottom: 2,
                                      right: 3,
                                      child: Icon(
                                        Icons.check,
                                        size: 14,
                                        color: AppColors.oliveLight,
                                      ),
                                    ),
                                  if (state == 'wrong')
                                    Positioned(
                                      bottom: 2,
                                      right: 3,
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: AppColors.claretLight,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ),
                ),
                // Clear / Hint over the selected word.
                ?_wordTools(cellSize),
              ],
            ),
          ),
        );
        if (!pan) {
          _panCellSize = null;
          _panViewport = null;
          return grid;
        }

        // Too big for the screen: a window onto the grid that can be
        // dragged and pinch-zoomed. It is as wide as the screen and up to
        // a fifth taller than it is wide.
        final gridWidth = _puzzle.cols * cellSize + 4;
        final gridHeight = _puzzle.rows * cellSize + 4;
        final viewport = Size(
          constraints.maxWidth,
          min(gridHeight, constraints.maxWidth * 1.2),
        );
        _panCellSize = cellSize;
        _panViewport = viewport;
        _scheduleReveal();
        void touching(bool on) {
          if (_touchingGrid != on) setState(() => _touchingGrid = on);
        }

        return Listener(
          onPointerDown: (_) => touching(true),
          onPointerUp: (_) => touching(false),
          onPointerCancel: (_) => touching(false),
          child: SizedBox(
            key: const Key('grid-window'),
            width: viewport.width,
            height: viewport.height,
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: _gridView,
                constrained: false,
                // Zoom out far enough to see the whole grid at once.
                minScale: viewport.width / gridWidth,
                maxScale: 2.5,
                boundaryMargin: EdgeInsets.zero,
                child: SizedBox(
                  width: gridWidth,
                  height: gridHeight,
                  child: grid,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Small Clear and Hint buttons floating just above the selected word
  /// (below it when it starts on the top row). Null when no word is
  /// selected or the word is already solved.
  Widget? _wordTools(double cellSize) {
    final clue = _activeClue();
    if (clue == null) return null;
    final cells = clue.cells
        .where((c) => !c.isBlack && c.answer != null)
        .toList();
    if (cells.isEmpty) return null;
    final solved = cells.every(
      (c) => _cellStates[_key(c.row, c.col)] == 'correct',
    );
    if (solved) return null;

    final r0 = cells.map((c) => c.row).reduce(min);
    final r1 = cells.map((c) => c.row).reduce(max);
    final c0 = cells.map((c) => c.col).reduce(min);
    const gap = 4.0;
    // Grid padding is 2 on every side.
    final wordTop = 2 + r0 * cellSize;
    final wordBottom = 2 + (r1 + 1) * cellSize;
    final gridHeight = _puzzle.rows * cellSize + 4;

    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _WordToolsLayout(
          left: 2 + c0 * cellSize,
          above: wordTop - gap,
          below: wordBottom + gap,
          gridHeight: gridHeight,
        ),
        child: KeyedSubtree(
          key: _wordToolsKey,
          child: NoWordLookUp(
            child: _WordTools(
              key: const Key('word-tools'),
              onClear: _clearSelectedWord,
              onHint: _revealHint,
              onCheck: _checkSelectedWord,
              onDictionary: _openDictionary,
            ),
          ),
        ),
      ),
    );
  }

  /// After the next frame, move the draggable grid so the selected square
  /// is in view (when the selection has changed since the last time).
  void _scheduleReveal() {
    final key = _selectedCellKey;
    if (key == null || key == _revealedCellKey) return;
    _revealedCellKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealCell(key);
    });
  }

  void _revealCell(String key) {
    final parts = key.split(',');
    final r = int.parse(parts[0]), c = int.parse(parts[1]);
    _revealArea(r, c, r, c);
  }

  /// Move the draggable grid so every square of [clue]'s word is in view,
  /// zooming out only if the word is too long to fit at the current size.
  void _revealWord(Clue clue) {
    final cells = clue.cells;
    if (cells.isEmpty) return;
    _revealArea(
      cells.map((x) => x.row).reduce(min),
      cells.map((x) => x.col).reduce(min),
      cells.map((x) => x.row).reduce(max),
      cells.map((x) => x.col).reduce(max),
    );
  }

  /// Move (and if needed zoom out) the draggable grid so the squares from
  /// row [r0], column [c0] to row [r1], column [c1] are all in view.
  void _revealArea(int r0, int c0, int r1, int c1) {
    final cell = _panCellSize;
    final view = _panViewport;
    if (cell == null || view == null) return;
    const margin = 8.0;
    // Room for the Clear | Hint | Check pill: it floats above the word, or
    // below it when the word starts on the top row.
    const toolsRoom = 40.0;
    final m = _gridView.value;
    final gridW0 = _puzzle.cols * cell + 4;
    final gridH0 = _puzzle.rows * cell + 4;
    final areaW = (c1 - c0 + 1) * cell;
    final areaH = (r1 - r0 + 1) * cell;
    final oldScale = m.getMaxScaleOnAxis();
    // Zoom out just enough for the area to fit (never past the whole grid).
    final fitScale = min(
      (view.width - 2 * margin) / areaW,
      // A tall word also needs room for the pill above or below it.
      (view.height - 2 * margin) / (areaH + toolsRoom),
    );
    final minScale = view.width / gridW0;
    final scale = oldScale > fitScale ? max(fitScale, minScale) : oldScale;
    var tx = m.getTranslation().x, ty = m.getTranslation().y;
    if (scale != oldScale) {
      // Keep the view's centre in place while zooming out.
      final cx = (view.width / 2 - tx) / oldScale;
      final cy = (view.height / 2 - ty) / oldScale;
      tx = view.width / 2 - cx * scale;
      ty = view.height / 2 - cy * scale;
    }
    // Shift so the area's right/bottom edge is in view, then its left/top
    // edge (which wins if both can't fit).
    final left = (2 + c0 * cell) * scale + tx;
    final top = (2 + r0 * cell) * scale + ty;
    final w = areaW * scale, h = areaH * scale;
    if (left + w > view.width - margin) tx -= left + w - (view.width - margin);
    final left2 = (2 + c0 * cell) * scale + tx;
    if (left2 < margin) tx += margin - left2;
    final topRoom = r0 > 0 ? margin + toolsRoom * scale : margin;
    final bottomRoom = r0 > 0 ? margin : margin + toolsRoom * scale;
    if (top + h > view.height - bottomRoom) {
      ty -= top + h - (view.height - bottomRoom);
    }
    final top2 = (2 + r0 * cell) * scale + ty;
    if (top2 < topRoom) ty += topRoom - top2;
    // Stay within the grid.
    tx = tx.clamp(min(view.width - gridW0 * scale, 0.0), 0.0);
    ty = ty.clamp(min(view.height - gridH0 * scale, 0.0), 0.0);
    if (scale == oldScale &&
        tx == m.getTranslation().x &&
        ty == m.getTranslation().y) {
      return;
    }
    _gridView.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(2, 2, scale)
      ..setTranslationRaw(tx, ty, 0);
  }

  // ── Clue list ─────────────────────────────────────────────────────────────

  Widget _buildClueList({
    required List<Clue> clues,
    required Brightness brightness,
    required Color gridCell,
    required Color hairline,
    required Color clay,
    required Color selected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: gridCell,
        borderRadius: BorderRadius.circular(Radius.sm),
        border: Border.all(color: hairline, width: 0.5),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Across / Down switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Each tab gets up to half the row and shrinks to fit it.
              Flexible(
                child: _clueHeaderButton(
                  label: (t) => t.acrossClues,
                  direction: _ClueDirection.across,
                  brightness: brightness,
                  clay: clay,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: _clueHeaderButton(
                  label: (t) => t.downClues,
                  direction: _ClueDirection.down,
                  brightness: brightness,
                  clay: clay,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ...clues.map((clue) {
            final isSelected = _selectedClue == clue;
            return Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: GestureDetector(
                onTap: () => _selectClue(clue),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? selected.withValues(alpha: 0.4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radius.sm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${clue.number}. ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: clay,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: clue.text,
                                children: [
                                  // Solved: the answer as a small button
                                  // right after the clue; tap it to open
                                  // its word page.
                                  if (_confirmedAnswer(clue) case final answer?)
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 6,
                                          top: 2,
                                          bottom: 2,
                                        ),
                                        child: _AnswerButton(
                                          key: Key('answer-$answer'),
                                          answer: answer,
                                          clay: clay,
                                          onTap: () => _openAnswer(answer),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                color: brightness.resolve(
                                  light: AppColors.inkLight,
                                  dark: AppColors.inkDark,
                                ),
                                height: 1.4,
                              ),
                            ),
                            _clueTranslation(clue, brightness),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Clue header button ────────────────────────────────────────────────────

  /// "ACROSS CLUES" / "DOWN CLUES" in the clue card header. The active one is
  /// clay with an underline; the other is muted. Tapping switches the list.
  /// The clue in the secondary language, on a small grey line underneath,
  /// when the secondary language is the clue's other language (English ↔
  /// Greek) and a translation is known.
  Widget _clueTranslation(Clue clue, Brightness brightness) {
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final other = _greek ? 'en' : 'el';
        final text = clue.translation;
        if (text == null || AppSettings.instance.secondaryLanguage != other) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: translationColor(context),
            ),
          ),
        );
      },
    );
  }

  Widget _clueHeaderButton({
    required TextPick label,
    required _ClueDirection direction,
    required Brightness brightness,
    required Color clay,
  }) {
    final active = _direction == direction;
    final muted = brightness.resolve(
      light: AppColors.mutedLight,
      dark: AppColors.mutedDark,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _direction = direction),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? clay : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DualText(
            label,
            inline: true,
            style: kickerStyle(brightness: brightness).copyWith(
              color: active ? clay : muted.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required TextPick label,
    required Color bg,
    required Color fg,
    required Color borderColor,
    required VoidCallback onTap,
    VoidCallback? onDoubleTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radius.sm),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Center(
          // Shrinks rather than wraps when three buttons share a row.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: DualText(
              label,
              crossAxisAlignment: CrossAxisAlignment.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: fg,
                fontFamily: 'Inter',
              ),
              // On the coloured Check button, the translation keeps the
              // button's text colour (a bit faded); elsewhere orange.
              secondaryStyle: TextStyle(
                fontSize: 12,
                color: fg == Colors.white
                    ? fg.withValues(alpha: 0.75)
                    : translationColor(context),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A solved answer in the clue list ("INDIC"), drawn as a small pill
/// button with a book icon so it reads as something to press: it opens the
/// word's page in the dictionary.
class _AnswerButton extends StatelessWidget {
  final String answer;
  final Color clay;
  final VoidCallback onTap;

  const _AnswerButton({
    super.key,
    required this.answer,
    required this.clay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: clay.withValues(alpha: 0.12),
      shape: StadiumBorder(side: BorderSide(color: clay, width: 0.8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                answer,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontFamily: 'Inter',
                  height: 1.2,
                  color: clay,
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.menu_book_outlined, size: 14, color: clay),
            ],
          ),
        ),
      ),
    );
  }
}

/// Places the word tools: lined up with the word's first column, just
/// above the word, or below it when there is no room above; always kept
/// inside the grid so they can be tapped.
class _WordToolsLayout extends SingleChildLayoutDelegate {
  final double left;
  final double above; // the bottom edge when placed above the word
  final double below; // the top edge when placed below the word
  final double gridHeight;

  _WordToolsLayout({
    required this.left,
    required this.above,
    required this.below,
    required this.gridHeight,
  });

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = left.clamp(0.0, max(0.0, size.width - child.width)).toDouble();
    final double y;
    if (above - child.height >= 0) {
      y = above - child.height;
    } else if (below + child.height <= size.height) {
      y = below;
    } else {
      y = 2; // the word fills the whole height: over its top
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_WordToolsLayout old) =>
      old.left != left ||
      old.above != above ||
      old.below != below ||
      old.gridHeight != gridHeight;
}

/// "Clear | Hint | Check" in a small floating pill; Check is the main
/// action, so it is filled in the accent colour.
class _WordTools extends StatelessWidget {
  final VoidCallback onClear;
  final VoidCallback onHint;
  final VoidCallback onCheck;
  final VoidCallback onDictionary;

  const _WordTools({
    super.key,
    required this.onClear,
    required this.onHint,
    required this.onCheck,
    required this.onDictionary,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = brightness.resolve(
      light: AppColors.inkLight,
      dark: AppColors.inkDark,
    );
    final t = AppText.of(context);
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      fontFamily: 'Inter',
      color: ink,
      height: 1.1,
    );

    // Clear is filled black with white letters, so it stands apart from
    // Hint; Check is filled in the accent colour.
    final onInk = brightness == Brightness.light
        ? Colors.white
        : AppColors.paperDark;

    Widget button(
      String label,
      Key key,
      VoidCallback onTap, {
      Color? background,
      Color? color,
    }) => Material(
      color: background ?? Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: color == null ? style : style.copyWith(color: color),
          ),
        ),
      ),
    );

    return Material(
      color: brightness.resolve(
        light: AppColors.gridCellLight,
        dark: AppColors.gridCellDark,
      ),
      elevation: 3,
      shadowColor: Colors.black38,
      shape: StadiumBorder(
        side: BorderSide(
          color: brightness.resolve(
            light: AppColors.hairlineLight,
            dark: AppColors.hairlineDark,
          ),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            t.clear,
            const Key('word-clear'),
            onClear,
            background: ink,
            color: onInk,
          ),
          button(t.hint, const Key('word-hint'), onHint),
          // Check: filled in the accent colour, the main action.
          Material(
            color: brightness.resolve(
              light: AppColors.clayLight,
              dark: AppColors.clayDark,
            ),
            child: InkWell(
              key: const Key('word-check'),
              onTap: onCheck,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Text(
                  t.check,
                  style: style.copyWith(
                    color: brightness == Brightness.light
                        ? Colors.white
                        : AppColors.paperDark,
                  ),
                ),
              ),
            ),
          ),
          // Look the word up in the dictionary with what's typed so far.
          InkWell(
            key: const Key('word-dictionary'),
            onTap: onDictionary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Icon(Icons.menu_book_outlined, size: 18, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
