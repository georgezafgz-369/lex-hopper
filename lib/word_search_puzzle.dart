// ─────────────────────────────────────────────────────────────────────────────
// FIND THE WORDS — data model, difficulty per level, and puzzle generator
// ─────────────────────────────────────────────────────────────────────────────
//
// A square grid of capital letters with words hidden in it. Words always
// read the normal way: left to right, top to bottom, or diagonally to the
// right (never backwards). Every other square is a filler letter, chosen so
// that no listed word appears a second time by accident.

import 'dart:math';

import 'crossword_puzzle.dart' show LevelSettings, WordCandidate, phraseGap;

// ──────────────────────────────────────────────────────────────────────────────
// DIRECTIONS
// ──────────────────────────────────────────────────────────────────────────────

/// The ways a word may run. All read forwards (left to right, or top to
/// bottom for [down]).
enum WordDirection {
  across(0, 1),
  down(1, 0),

  /// Diagonally down and to the right.
  diagonalDown(1, 1),

  /// Diagonally up and to the right (still read left to right).
  diagonalUp(-1, 1);

  final int dRow;
  final int dCol;
  const WordDirection(this.dRow, this.dCol);
}

// ──────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ──────────────────────────────────────────────────────────────────────────────

/// One word hidden in the grid: where it starts and which way it runs.
class HiddenWord {
  final String word; // capitals, as in the grid
  final String clue; // its meaning (for the word page and translations)
  final String? clueTr; // the meaning in the other language, if known
  final String? wordTr; // the word in the other language, if known
  final int row;
  final int col;
  final WordDirection direction;

  HiddenWord({
    required String word,
    required this.clue,
    this.clueTr,
    this.wordTr,
    required this.row,
    required this.col,
    required this.direction,
  }) : word = word.toUpperCase();

  /// The grid squares it covers, first letter first, as (row, col).
  List<(int, int)> get cells => [
    for (var i = 0; i < word.length; i++)
      (row + direction.dRow * i, col + direction.dCol * i),
  ];

  Map<String, dynamic> toJson() => {
    'word': word,
    'clue': clue,
    if (clueTr != null) 'clueTr': clueTr,
    if (wordTr != null) 'wordTr': wordTr,
    'row': row,
    'col': col,
    'direction': direction.name,
  };

  factory HiddenWord.fromJson(Map<String, dynamic> json) => HiddenWord(
    word: json['word'] as String,
    clue: json['clue'] as String,
    clueTr: json['clueTr'] as String?,
    wordTr: json['wordTr'] as String?,
    row: json['row'] as int,
    col: json['col'] as int,
    direction: WordDirection.values.byName(json['direction'] as String),
  );
}

/// A complete Find the Words puzzle.
class WordSearchPuzzle {
  final int level;
  final int size;

  /// The letters, row by row ([size] × [size]).
  final List<String> letters;

  /// The words to find, in the order they are listed.
  final List<HiddenWord> words;

  WordSearchPuzzle({
    required this.level,
    required this.size,
    required List<String> letters,
    required List<HiddenWord> words,
  }) : letters = List.unmodifiable(letters),
       words = List.unmodifiable(words);

  String letterAt(int row, int col) => letters[row * size + col];

  /// The listed word spelled by the squares from (r0, c0) to (r1, c1), if
  /// they form a straight line that matches one exactly. Lines drawn
  /// backwards (end to start) also count: the player may drag either way.
  HiddenWord? wordAt(int r0, int c0, int r1, int c1) {
    for (final w in words) {
      final first = w.cells.first, last = w.cells.last;
      if ((first == (r0, c0) && last == (r1, c1)) ||
          (first == (r1, c1) && last == (r0, c0))) {
        return w;
      }
    }
    return null;
  }

  /// The same set of words gives the same signature (used to avoid serving
  /// an identical puzzle twice).
  String get signature => (words.map((w) => w.word).toList()..sort()).join(',');

  Map<String, dynamic> toJson() => {
    'level': level,
    'size': size,
    'letters': letters.join(),
    'words': words.map((w) => w.toJson()).toList(),
  };

  factory WordSearchPuzzle.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as int;
    final letters = (json['letters'] as String).split('');
    return WordSearchPuzzle(
      level: json['level'] as int,
      size: size,
      letters: letters,
      words: [
        for (final w in json['words'] as List)
          HiddenWord.fromJson(w as Map<String, dynamic>),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DIFFICULTY PER LEVEL
// ──────────────────────────────────────────────────────────────────────────────

class WordSearchLevel {
  final int gridSize;
  final int targetWords;
  final int minLen;
  final int maxLen;
  final int minRank;
  final int maxRank;
  final List<WordDirection> directions;

  const WordSearchLevel({
    required this.gridSize,
    required this.targetWords,
    required this.minLen,
    required this.maxLen,
    required this.minRank,
    required this.maxRank,
    required this.directions,
  });

  //  Level   Grid    Words   Directions
  //    1     6×6       5     across, down
  //    2     7×7       6     across, down
  //    3     8×8       8     + diagonal down-right
  //    4     9×9      10     + diagonal down-right
  //    5    10×10     12     + diagonal up-right
  //    6    11×11     14     all four
  //    7+   12×12     15     all four
  //  Words get rarer each level, with the crossword's commonness windows
  //  (see LevelSettings.forLevel), except that English stops at the
  //  12,000 most common words (ranks 3,000–12,000 from level 4): the list
  //  shows the words themselves, with no clue to help, and rarer English
  //  words (jawfishes, anobiidae) feel random. The Greek list holds common
  //  words only, so it keeps the crossword's windows.
  factory WordSearchLevel.forLevel(int level, {int? poolSize}) {
    final l = max(1, level);
    final grid = min(5 + l, 12);
    const words = {6: 5, 7: 6, 8: 8, 9: 10, 10: 12, 11: 14, 12: 15};
    final ranks = LevelSettings.forLevel(l, poolSize: poolSize);
    return WordSearchLevel(
      gridSize: grid,
      targetWords: words[grid]!,
      minLen: 3,
      maxLen: min(grid, 10),
      minRank: poolSize == null ? min(ranks.minRank, 3000) : ranks.minRank,
      maxRank: poolSize == null ? min(ranks.maxRank, 12000) : ranks.maxRank,
      directions: [
        WordDirection.across,
        WordDirection.down,
        if (l >= 3) WordDirection.diagonalDown,
        if (l >= 5) WordDirection.diagonalUp,
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// GENERATOR
// ──────────────────────────────────────────────────────────────────────────────

/// The letters puzzles are filled with, per language.
const englishAlphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const greekAlphabet = 'ΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ';
const russianAlphabet = 'АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ';
const spanishAlphabet = 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ';

/// The letters of [language]'s puzzles (the answers are written without
/// accents, see crosswordLetter).
String alphabetFor(String language) => switch (language) {
  'el' => greekAlphabet,
  'ru' => russianAlphabet,
  'es' => spanishAlphabet,
  _ => englishAlphabet,
};

class WordSearchGenerator {
  final int size;
  final List<WordDirection> directions;
  final String alphabet;
  final Random random;

  WordSearchGenerator({
    required this.size,
    required this.directions,
    this.alphabet = englishAlphabet,
    Random? random,
  }) : random = random ?? Random();

  /// Hide up to [targetWords] of [candidates] in a grid and fill the rest.
  /// Null if not even [minWords] could be placed.
  WordSearchPuzzle? make(
    List<WordCandidate> candidates, {
    required int level,
    required int targetWords,
    int minWords = 3,
    int attempts = 30,
  }) {
    final usable = _usable(candidates);
    WordSearchPuzzle? best;
    for (var a = 0; a < attempts; a++) {
      final placed = _place(usable, targetWords);
      if (placed == null) continue;
      final letters = _fill(placed.$1, placed.$2);
      if (letters == null) continue;
      final puzzle = WordSearchPuzzle(
        level: level,
        size: size,
        letters: letters,
        words: placed.$2,
      );
      if (best == null || puzzle.words.length > best.words.length) {
        best = puzzle;
      }
      if (best.words.length >= targetWords) break;
    }
    return (best != null && best.words.length >= minWords) ? best : null;
  }

  /// Plain words (no phrases or other characters) that fit the grid.
  List<WordCandidate> _usable(List<WordCandidate> candidates) {
    final seen = <String>{};
    return [
      for (final c in candidates)
        if (!c.word.contains(phraseGap) &&
            c.word.length >= 3 &&
            c.word.length <= size &&
            c.word.toUpperCase().split('').every(alphabet.contains) &&
            seen.add(c.word.toUpperCase()))
          c,
    ];
  }

  /// Place words one by one (longest first) at random spots and directions,
  /// crossing where their letters agree. Skips a word that is part of an
  /// already chosen one (or contains one), since finding it would be
  /// ambiguous. Returns the grid (null = free square) and the words.
  (List<String?>, List<HiddenWord>)? _place(
    List<WordCandidate> pool,
    int target,
  ) {
    final shuffled = List.of(pool)..shuffle(random);
    final picks = <WordCandidate>[];
    for (final c in shuffled) {
      final w = c.word.toUpperCase();
      if (picks.any((p) {
        final pw = p.word.toUpperCase();
        return pw.contains(w) || w.contains(pw);
      })) {
        continue;
      }
      picks.add(c);
      // A few spares, for words that won't fit.
      if (picks.length >= target * 2) break;
    }
    picks.sort((a, b) => b.word.length.compareTo(a.word.length));

    final grid = List<String?>.filled(size * size, null);
    final placed = <HiddenWord>[];
    for (final c in picks) {
      if (placed.length >= target) break;
      final word = c.word.toUpperCase();
      final spot = _spotFor(word, grid);
      if (spot == null) continue;
      final (r, col, dir) = spot;
      for (var i = 0; i < word.length; i++) {
        grid[(r + dir.dRow * i) * size + (col + dir.dCol * i)] = word[i];
      }
      placed.add(
        HiddenWord(
          word: word,
          clue: c.clue,
          clueTr: c.clueTr,
          wordTr: c.wordTr,
          row: r,
          col: col,
          direction: dir,
        ),
      );
    }
    if (placed.isEmpty) return null;
    // List them alphabetically, like a printed word search.
    placed.sort((a, b) => a.word.compareTo(b.word));
    return (grid, placed);
  }

  /// A random start and direction where [word] fits: inside the grid, and
  /// only crossing squares that already hold the same letter.
  (int, int, WordDirection)? _spotFor(String word, List<String?> grid) {
    final options = <(int, int, WordDirection)>[];
    for (final dir in directions) {
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          final endR = r + dir.dRow * (word.length - 1);
          final endC = c + dir.dCol * (word.length - 1);
          if (endR < 0 || endR >= size || endC >= size) continue;
          var ok = true;
          for (var i = 0; i < word.length && ok; i++) {
            final have = grid[(r + dir.dRow * i) * size + (c + dir.dCol * i)];
            if (have != null && have != word[i]) ok = false;
          }
          if (ok) options.add((r, c, dir));
        }
      }
    }
    if (options.isEmpty) return null;
    return options[random.nextInt(options.length)];
  }

  /// Fill the free squares. Filler letters follow the hidden words' own
  /// letter mix (half the time) or the plain alphabet, so they blend in.
  /// Null if after several tries a listed word still shows up twice.
  List<String>? _fill(List<String?> grid, List<HiddenWord> words) {
    final mix = words.map((w) => w.word).join();
    for (var t = 0; t < 20; t++) {
      final letters = [
        for (final g in grid)
          g ??
              (random.nextBool()
                  ? mix[random.nextInt(mix.length)]
                  : alphabet[random.nextInt(alphabet.length)]),
      ];
      if (words.every((w) => _count(letters, w.word) == 1)) return letters;
    }
    return null;
  }

  /// How many times [word] can be read in [letters] along the allowed
  /// directions.
  int _count(List<String> letters, String word) {
    var n = 0;
    for (final dir in directions) {
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          final endR = r + dir.dRow * (word.length - 1);
          final endC = c + dir.dCol * (word.length - 1);
          if (endR < 0 || endR >= size || endC >= size) continue;
          var match = true;
          for (var i = 0; i < word.length && match; i++) {
            if (letters[(r + dir.dRow * i) * size + (c + dir.dCol * i)] !=
                word[i]) {
              match = false;
            }
          }
          if (match) n++;
        }
      }
    }
    return n;
  }
}
