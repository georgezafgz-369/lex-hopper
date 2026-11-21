// Crossword generator, difficulty curve, and save round-trip.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lex_hopper/crossword_puzzle.dart';

const _words = [
  'apple',
  'table',
  'chair',
  'plate',
  'river',
  'stone',
  'light',
  'water',
  'tree',
  'rain',
  'snow',
  'wind',
  'cat',
  'dog',
  'sun',
  'sea',
  'tea',
  'pen',
  'ink',
  'oak',
  'elm',
  'ant',
  'bee',
  'owl',
  'ear',
  'eye',
  'arm',
  'leg',
  'bread',
  'cloud',
  'grass',
  'house',
  'mouse',
  'horse',
  'night',
  'ocean',
];

List<WordCandidate> get candidates => [
  for (final w in _words) WordCandidate(w, 'Clue for $w'),
];

/// Every placed letter must agree with the grid, every word must cross
/// another, and no answer may touch another side by side.
void expectValidLayout(List<PuzzleEntry> entries, int size) {
  final letters = <(int, int), String>{};
  for (final e in entries) {
    for (var i = 0; i < e.word.length; i++) {
      final cell = (e.row + (e.across ? 0 : i), e.col + (e.across ? i : 0));
      expect(cell.$1, inInclusiveRange(0, size - 1));
      expect(cell.$2, inInclusiveRange(0, size - 1));
      final existing = letters[cell];
      expect(
        existing == null || existing == e.word[i],
        isTrue,
        reason: 'letter clash at $cell',
      );
      letters[cell] = e.word[i];
    }
  }
  // Every run of 2+ letters in the grid must be one of the answers.
  final answers = entries.map((e) => (e.word, e.row, e.col, e.across)).toSet();
  for (final across in [true, false]) {
    for (var line = 0; line < size; line++) {
      var start = 0;
      while (start < size) {
        (int, int) at(int k) => across ? (line, k) : (k, line);
        if (!letters.containsKey(at(start))) {
          start++;
          continue;
        }
        var end = start;
        while (end + 1 < size && letters.containsKey(at(end + 1))) {
          end++;
        }
        if (end > start) {
          final word = [for (var k = start; k <= end; k++) letters[at(k)]]
              .join();
          final (r, c) = at(start);
          expect(
            answers.contains((word, r, c, across)),
            isTrue,
            reason: 'stray word "$word" at ($r,$c)',
          );
        }
        start = end + 1;
      }
    }
  }
}

void main() {
  test('generator builds valid, connected grids', () {
    for (var seed = 0; seed < 40; seed++) {
      final size = 5 + seed % 5;
      final entries = CrosswordGenerator(
        size: size,
        random: Random(seed),
      ).layout(candidates, targetWords: 6);
      expect(entries, isNotNull, reason: 'seed $seed');
      expect(entries!.length, greaterThanOrEqualTo(3));
      expectValidLayout(entries, size);
    }
  });

  test('different seeds give different word sets', () {
    final sets = {
      for (var seed = 0; seed < 10; seed++)
        CrosswordPuzzle.fromEntries(
          level: 1,
          size: 7,
          entries: CrosswordGenerator(
            size: 7,
            random: Random(seed),
          ).layout(candidates, targetWords: 6)!,
        ).signature,
    };
    expect(sets.length, greaterThan(5));
  });

  test('difficulty rises with level', () {
    final l1 = LevelSettings.forLevel(1);
    final l3 = LevelSettings.forLevel(3);
    final l6 = LevelSettings.forLevel(6);
    expect(l1.gridSize, 5);
    expect(l1.maxLen, 5);
    expect(l1.minRank, 1);
    expect(l3.gridSize, greaterThan(l1.gridSize));
    expect(l3.targetWords, greaterThan(l1.targetWords));
    expect(l3.maxRank, greaterThan(l1.maxRank));
    expect(l6.minRank, greaterThan(l3.minRank)); // rarer words only
    expect(l6.gridSize, 10);
    // Grids grow to 13×13 and stay there; words up to 11 letters.
    expect(LevelSettings.forLevel(9).gridSize, 13);
    expect(LevelSettings.forLevel(30).gridSize, 13);
    expect(LevelSettings.forLevel(30).maxLen, 11);
    expect(LevelSettings.forLevel(9).targetWords, 17);
  });

  test('numbering and save round-trip', () {
    final puzzle = CrosswordPuzzle.fromEntries(
      level: 2,
      size: 5,
      entries: [
        PuzzleEntry(word: 'apple', clue: 'Fruit', row: 0, col: 0, across: true),
        PuzzleEntry(word: 'pet', clue: 'Animal', row: 0, col: 1, across: false),
      ],
    );
    expect(puzzle.across.single.number, 1);
    expect(puzzle.down.single.number, 2);
    expect(puzzle.cellAt(0, 1)!.answer, 'P');

    final copy = CrosswordPuzzle.fromJson(puzzle.toJson());
    expect(copy.signature, puzzle.signature);
    expect(copy.level, 2);
    expect(copy.down.single.text, 'Animal');
  });

  test('phrases: the space is a black square no other word crosses', () {
    final candidates = [
      const WordCandidate('give#up', 'Stop trying'),
      const WordCandidate('ice#cream', 'Frozen dessert'),
      ..._words.map((w) => WordCandidate(w, 'clue for $w')),
    ];
    var sawPhrase = false;
    for (var seed = 0; seed < 40; seed++) {
      final entries = CrosswordGenerator(
        size: 9,
        random: Random(seed),
      ).layout(candidates, targetWords: 12)!;
      final puzzle = CrosswordPuzzle.fromEntries(
        level: 5,
        size: 9,
        entries: entries,
      );
      for (final e in entries.where((e) => e.word.contains(phraseGap))) {
        sawPhrase = true;
        final gapIndex = e.word.indexOf(phraseGap);
        final r = e.row + (e.across ? 0 : gapIndex);
        final c = e.col + (e.across ? gapIndex : 0);
        final cell = puzzle.cellAt(r, c)!;
        expect(cell.isGap, isTrue);
        expect(cell.isBlack, isTrue);
        // No other answer runs through the gap.
        final through = entries.where((o) {
          if (identical(o, e)) return false;
          for (var i = 0; i < o.word.length; i++) {
            final rr = o.row + (o.across ? 0 : i);
            final cc = o.col + (o.across ? i : 0);
            if (rr == r && cc == c) return true;
          }
          return false;
        });
        expect(through, isEmpty);
      }
    }
    expect(sawPhrase, isTrue);
  });

  test('phrases only from level 5', () {
    expect(LevelSettings.forLevel(4).phrases, isFalse);
    expect(LevelSettings.forLevel(5).phrases, isTrue);
  });
}
