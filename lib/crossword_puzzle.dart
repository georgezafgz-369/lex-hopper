// ─────────────────────────────────────────────────────────────────────────────
// CROSSWORD PUZZLE — data model, difficulty per level, and grid generator
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

// ──────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ──────────────────────────────────────────────────────────────────────────────

/// A single cell in the crossword grid.
class GridCell {
  final int row;
  final int col;
  final bool isBlack;

  /// A black square inside a phrase answer, where the space goes
  /// (PIECE■OF■CAKE). Drawn in ink, unlike the empty spaces of the grid.
  final bool isGap;
  final int? clueNumber; // null if no clue starts here
  final String? answer; // the correct letter (null for black cells)

  GridCell({
    required this.row,
    required this.col,
    this.isBlack = false,
    this.isGap = false,
    this.clueNumber,
    this.answer,
  });
}

/// In a phrase answer, the space between words is stored as this character
/// ("GIVE#UP") and becomes a black square in the grid.
const phraseGap = '#';

/// A clue (across or down).
class Clue {
  final int number;
  final String text;

  /// The clue in the other language (English ↔ Greek), when there is one.
  final String? translation;
  final List<GridCell> cells;

  Clue({
    required this.number,
    required this.text,
    this.translation,
    required this.cells,
  });
}

/// One answer placed in the grid. This is all a puzzle needs to be rebuilt,
/// so it is what gets saved.
class PuzzleEntry {
  final String word; // upper case
  final String clue;

  /// The clue in the other language (English ↔ Greek), if known.
  final String? clueTr;
  final int row;
  final int col;
  final bool across;

  PuzzleEntry({
    required String word,
    required this.clue,
    this.clueTr,
    required this.row,
    required this.col,
    required this.across,
  }) : word = word.toUpperCase();

  Map<String, dynamic> toJson() => {
    'word': word,
    'clue': clue,
    if (clueTr != null) 'clueTr': clueTr,
    'row': row,
    'col': col,
    'across': across,
  };

  factory PuzzleEntry.fromJson(Map<String, dynamic> json) => PuzzleEntry(
    word: json['word'] as String,
    clue: json['clue'] as String,
    clueTr: json['clueTr'] as String?,
    row: json['row'] as int,
    col: json['col'] as int,
    across: json['across'] as bool,
  );
}

/// A complete crossword puzzle.
class CrosswordPuzzle {
  final int level;
  final int cols;
  final int rows;
  final List<GridCell> grid;
  final List<Clue> across;
  final List<Clue> down;
  final List<PuzzleEntry> entries;

  CrosswordPuzzle._({
    required this.level,
    required this.cols,
    required this.rows,
    required this.grid,
    required this.across,
    required this.down,
    required this.entries,
  });

  /// Build the grid, numbering and clue lists from placed answers.
  factory CrosswordPuzzle.fromEntries({
    required int level,
    required int size,
    required List<PuzzleEntry> entries,
  }) {
    // Number start cells in reading order (shared by across + down starts).
    final starts = entries.map((e) => e.row * size + e.col).toSet().toList()
      ..sort();
    final numberAt = {for (var i = 0; i < starts.length; i++) starts[i]: i + 1};

    // Letters per cell.
    final letters = <int, String>{};
    for (final e in entries) {
      for (var i = 0; i < e.word.length; i++) {
        final r = e.row + (e.across ? 0 : i);
        final c = e.col + (e.across ? i : 0);
        letters[r * size + c] = e.word[i];
      }
    }

    final grid = List.generate(size * size, (idx) {
      final r = idx ~/ size;
      final c = idx % size;
      final letter = letters[idx];
      if (letter == null) return GridCell(row: r, col: c, isBlack: true);
      if (letter == phraseGap) {
        return GridCell(row: r, col: c, isBlack: true, isGap: true);
      }
      return GridCell(
        row: r,
        col: c,
        answer: letter,
        clueNumber: numberAt[idx],
      );
    });

    Clue toClue(PuzzleEntry e) => Clue(
      number: numberAt[e.row * size + e.col]!,
      text: e.clue,
      translation: e.clueTr,
      cells: List.generate(e.word.length, (i) {
        final r = e.row + (e.across ? 0 : i);
        final c = e.col + (e.across ? i : 0);
        return grid[r * size + c];
      }),
    );

    List<Clue> sorted(Iterable<Clue> clues) =>
        clues.toList()..sort((a, b) => a.number.compareTo(b.number));

    return CrosswordPuzzle._(
      level: level,
      cols: size,
      rows: size,
      grid: grid,
      across: sorted(entries.where((e) => e.across).map(toClue)),
      down: sorted(entries.where((e) => !e.across).map(toClue)),
      entries: List.unmodifiable(entries),
    );
  }

  /// The cell at [r],[c], or null when outside the grid.
  GridCell? cellAt(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    return grid[r * cols + c];
  }

  /// Identifies the set of words, regardless of layout. Two puzzles with the
  /// same signature use exactly the same words.
  String get signature =>
      (entries.map((e) => e.word).toList()..sort()).join(',');

  Map<String, dynamic> toJson() => {
    'level': level,
    'size': cols,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory CrosswordPuzzle.fromJson(Map<String, dynamic> json) =>
      CrosswordPuzzle.fromEntries(
        level: json['level'] as int,
        size: json['size'] as int,
        entries: (json['entries'] as List)
            .map((e) => PuzzleEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// DIFFICULTY
// ──────────────────────────────────────────────────────────────────────────────

/// How hard a level is. Difficulty rises on three fronts at once:
/// rarer words, longer words, and a bigger grid with more answers.
class LevelSettings {
  final int gridSize;
  final int targetWords;
  final int minLen;
  final int maxLen;

  /// Commonness window: rank 1 is the most common word in the dictionary.
  final int minRank;
  final int maxRank;

  /// Whether phrases ("give up", "ice cream") may be answers (Level 5+).
  final bool phrases;

  const LevelSettings({
    required this.gridSize,
    required this.targetWords,
    required this.minLen,
    required this.maxLen,
    required this.minRank,
    required this.maxRank,
    this.phrases = false,
  });

  /// How many answers to aim for on each grid size.
  static const _wordsFor = {
    5: 4,
    6: 6,
    7: 8,
    8: 9,
    9: 11,
    10: 12,
    11: 13,
    12: 15,
    13: 17,
  };

  /// First level whose puzzles can contain phrases.
  static const phrasesFromLevel = 5;

  //  Level   Grid   Words   Length   Word ranks (1 = most common)
  //    1     5×5      4      3–5         1 – 1,500
  //    2     6×6      6      3–6         1 – 3,000
  //    3     7×7      8      3–7     1,500 – 6,000
  //    4     8×8      9      4–8     3,000 – 12,000
  //    5     9×9     11      4–9     6,000 – 24,000
  //    6    10×10    12      4–10        … rarer
  //    7    11×11    13      5–11        … rarer
  //    8    12×12    15      5–11        … rarer
  //    9+   13×13    17      5–11    … up to the rarest words
  //  From level 5, a few phrases join the pool (spaces become black squares).
  //  The word counts are what each grid size can usually hold (measured);
  //  a puzzle that doesn't fill them all keeps the best layout found.
  //  Grids too big for the screen sit in a window that can be dragged.
  //
  //  [poolSize]: how many answers the dictionary has, when it is small (the
  //  Greek one has ~5,300). Its windows start at 1,000 and double each
  //  level, until the later levels use the rarer half of all its words.
  factory LevelSettings.forLevel(int level, {int? poolSize}) {
    final l = max(1, level);
    final grid = min(4 + l, 13);
    final maxRank = poolSize == null
        ? min(1500 * pow(2, l - 1).toInt(), 70000)
        : min(1000 * pow(2, min(l, 20) - 1).toInt(), poolSize);
    final minRank = l <= 2
        ? 1
        : poolSize == null
        ? maxRank ~/ 4
        : min(maxRank ~/ 4, poolSize ~/ 2);
    return LevelSettings(
      gridSize: grid,
      targetWords: _wordsFor[grid]!,
      minLen: min(3 + (l - 1) ~/ 3, 5),
      maxLen: min(grid, 11),
      minRank: minRank,
      maxRank: maxRank,
      phrases: l >= phrasesFromLevel,
    );
  }
}

/// A word the generator may use, with its clue.
class WordCandidate {
  final String word;
  final String clue;

  /// The clue in the other language (English ↔ Greek), if known.
  final String? clueTr;

  /// The word itself in the other language (bread → ψωμί), if known.
  final String? wordTr;
  const WordCandidate(this.word, this.clue, [this.clueTr, this.wordTr]);
}

// ──────────────────────────────────────────────────────────────────────────────
// GENERATOR
// ──────────────────────────────────────────────────────────────────────────────

/// Lays out candidate words on a square grid, crossword style: every new word
/// crosses one already placed, letters agree where words cross, and no two
/// answers touch side by side (which would spell nonsense words).
class CrosswordGenerator {
  final int size;
  final Random random;

  CrosswordGenerator({required this.size, Random? random})
    : random = random ?? Random();

  /// Try [attempts] layouts and return the one with the most words (stopping
  /// early once [targetWords] fit, or once [timeLimit] has passed). Null if
  /// not even [minWords] fit.
  List<PuzzleEntry>? layout(
    List<WordCandidate> candidates, {
    required int targetWords,
    int minWords = 3,
    int attempts = 60,
    Duration? timeLimit,
  }) {
    final usable = candidates
        .where((w) => w.word.length >= 2 && w.word.length <= size)
        .toList();
    final clock = Stopwatch()..start();
    List<PuzzleEntry>? best;
    for (var a = 0; a < attempts; a++) {
      final result = _attempt(usable, targetWords);
      if (best == null || result.length > best.length) best = result;
      if (best.length >= targetWords) break;
      if (timeLimit != null && clock.elapsed > timeLimit) break;
    }
    return (best != null && best.length >= minWords) ? best : null;
  }

  List<PuzzleEntry> _attempt(List<WordCandidate> candidates, int target) {
    if (candidates.isEmpty) return const [];
    final pool = List.of(candidates)..shuffle(random);
    // Try up to two phrases first, so puzzles that may have phrases
    // usually get one (they're long and rarely fit once the grid fills).
    final phrases = pool.where((w) => w.word.contains(phraseGap)).take(2);
    for (final p in phrases.toList()) {
      pool
        ..remove(p)
        ..insert(1, p);
    }
    final letters = List<String?>.filled(size * size, null);
    final usedAcross = List<bool>.filled(size * size, false);
    final usedDown = List<bool>.filled(size * size, false);
    final placed = <PuzzleEntry>[];

    String? at(int r, int c) => (r < 0 || r >= size || c < 0 || c >= size)
        ? null
        : letters[r * size + c];

    void place(WordCandidate w, int r, int c, bool across) {
      final word = w.word.toUpperCase();
      for (var i = 0; i < word.length; i++) {
        final idx = (r + (across ? 0 : i)) * size + (c + (across ? i : 0));
        letters[idx] = word[i];
        (across ? usedAcross : usedDown)[idx] = true;
      }
      placed.add(
        PuzzleEntry(
          word: word,
          clue: w.clue,
          clueTr: w.clueTr,
          row: r,
          col: c,
          across: across,
        ),
      );
    }

    /// Number of crossings if [word] fits at r,c; -1 if it doesn't.
    int fit(String word, int r, int c, bool across) {
      final dr = across ? 0 : 1, dc = across ? 1 : 0;
      final r2 = r + dr * (word.length - 1), c2 = c + dc * (word.length - 1);
      if (r < 0 || c < 0 || r2 >= size || c2 >= size) return -1;
      if (at(r - dr, c - dc) != null || at(r2 + dr, c2 + dc) != null) return -1;
      var crossings = 0;
      for (var i = 0; i < word.length; i++) {
        final rr = r + dr * i, cc = c + dc * i;
        final existing = at(rr, cc);
        if (existing != null) {
          // Phrase gaps (black squares) are never shared with another word.
          if (existing == phraseGap || word[i] == phraseGap) return -1;
          if (existing != word[i]) return -1;
          if ((across ? usedAcross : usedDown)[rr * size + cc]) return -1;
          crossings++;
        } else if (at(rr + dc, cc + dr) != null ||
            at(rr - dc, cc - dr) != null) {
          return -1; // would sit right beside another answer
        }
      }
      return crossings == word.length ? -1 : crossings;
    }

    bool tooSimilar(String word) => placed.any((p) {
      final a = p.word, b = word;
      return a == b ||
          ((a.startsWith(b) || b.startsWith(a)) &&
              (a.length - b.length).abs() <= 2); // CAT vs CATS
    });

    // First word: across, on a random row.
    final first = pool.removeAt(0);
    place(
      first,
      random.nextInt(size),
      random.nextInt(size - first.word.length + 1),
      true,
    );

    // Then anything that crosses what's there; two passes over the pool.
    for (var pass = 0; pass < 2 && placed.length < target; pass++) {
      for (final w in pool) {
        if (placed.length >= target) break;
        final word = w.word.toUpperCase();
        if (tooSimilar(word)) continue;

        var bestScore = 0;
        final options = <(int, int, bool)>[];
        for (var idx = 0; idx < letters.length; idx++) {
          final letter = letters[idx];
          if (letter == null || letter == phraseGap) continue;
          for (var i = 0; i < word.length; i++) {
            if (word[i] != letter) continue;
            for (final across in const [true, false]) {
              final r = idx ~/ size - (across ? 0 : i);
              final c = idx % size - (across ? i : 0);
              final score = fit(word, r, c, across);
              if (score <= 0 || score < bestScore) continue;
              if (score > bestScore) options.clear();
              bestScore = score;
              options.add((r, c, across));
            }
          }
        }
        if (options.isEmpty) continue;
        final (r, c, across) = options[random.nextInt(options.length)];
        place(w, r, c, across);
      }
    }
    return placed;
  }
}
