// Find the Words puzzles: words read forwards only, each listed word appears
// exactly once, the grid is full of letters of the right alphabet, levels
// grow, and both dictionaries can fill every level.

// ignore_for_file: avoid_print

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'lexicon_sql.dart';

import 'package:lex_hopper/crossword_puzzle.dart';
import 'package:lex_hopper/word_search_puzzle.dart';

/// How many times [word] reads forwards in [p]: left to right, top to
/// bottom, or diagonally to the right (whatever the level allows).
int countAll(WordSearchPuzzle p, String word) {
  var n = 0;
  for (final (dr, dc) in [(0, 1), (1, 0), (1, 1), (-1, 1)]) {
    for (var r = 0; r < p.size; r++) {
      for (var c = 0; c < p.size; c++) {
        var ok = true;
        for (var i = 0; i < word.length && ok; i++) {
          final rr = r + dr * i, cc = c + dc * i;
          if (rr < 0 || rr >= p.size || cc < 0 || cc >= p.size) {
            ok = false;
          } else if (p.letterAt(rr, cc) != word[i]) {
            ok = false;
          }
        }
        if (ok) n++;
      }
    }
  }
  return n;
}

void checkPuzzle(WordSearchPuzzle p, WordSearchLevel s, String alphabet) {
  expect(p.letters.length, p.size * p.size);
  expect(p.letters.every(alphabet.contains), isTrue, reason: 'alphabet');
  for (final w in p.words) {
    expect(s.directions, contains(w.direction));
    // Its squares spell it, inside the grid.
    for (final (i, (r, c)) in w.cells.indexed) {
      expect(p.letterAt(r, c), w.word[i]);
    }
    // Found exactly once reading forwards: no second copy to confuse.
    expect(countAll(p, w.word), 1, reason: '${w.word} once');
  }
  // No listed word hides inside another.
  for (final a in p.words) {
    for (final b in p.words) {
      if (a != b) expect(a.word.contains(b.word), isFalse);
    }
  }
}

List<WordCandidate> dbCandidates(String lang, WordSearchLevel s) {
  final out = puzzleSql(
    lang,
    'SELECT word, clue FROM puzzle_words WHERE phrase = 0 '
    'AND len BETWEEN ${s.minLen} AND ${s.maxLen} '
    'AND rank BETWEEN ${s.minRank} AND ${s.maxRank} '
    'ORDER BY RANDOM() LIMIT 400',
  );
  return [
    for (final line in out.split('\n'))
      if (line.contains('\t'))
        WordCandidate(line.split('\t')[0], line.split('\t')[1]),
  ];
}

int poolSize(String lang) => int.parse(
  puzzleSql(lang, 'SELECT max(rank) FROM puzzle_words WHERE phrase = 0'),
);

void main() {
  test('levels grow; diagonals from level 3, up-right from level 5', () {
    final l1 = WordSearchLevel.forLevel(1);
    expect(l1.gridSize, 6);
    expect(l1.targetWords, 5);
    expect(l1.directions, [WordDirection.across, WordDirection.down]);
    expect(
      WordSearchLevel.forLevel(3).directions,
      contains(WordDirection.diagonalDown),
    );
    expect(
      WordSearchLevel.forLevel(4).directions,
      isNot(contains(WordDirection.diagonalUp)),
    );
    expect(WordSearchLevel.forLevel(5).directions, hasLength(4));
    expect(WordSearchLevel.forLevel(7).gridSize, 12);
    expect(WordSearchLevel.forLevel(40).gridSize, 12);
    expect(WordSearchLevel.forLevel(40).targetWords, 15);
    // English stays within the 12,000 most common words.
    expect(WordSearchLevel.forLevel(1).maxRank, 1500);
    expect(WordSearchLevel.forLevel(4).maxRank, 12000);
    expect(WordSearchLevel.forLevel(40).maxRank, 12000);
    expect(WordSearchLevel.forLevel(40).minRank, 3000);
  });

  test('a puzzle from given words follows the rules', () {
    final s = WordSearchLevel.forLevel(5);
    final words = [
      'APPLE',
      'BREAD',
      'CHEESE',
      'BANANA',
      'ORANGE',
      'PIZZA',
      'SALAD',
      'BUTTER',
      'COOKIE',
      'MANGO',
      'HONEY',
      'LEMON',
      'PASTA',
      'TOAST',
      'MUFFIN',
      'SOUP',
      'RICE',
      'CAKE',
      'PEAR',
      'PLUM',
    ];
    for (var seed = 0; seed < 20; seed++) {
      final p =
          WordSearchGenerator(
            size: s.gridSize,
            directions: s.directions,
            random: Random(seed),
          ).make(
            [for (final w in words) WordCandidate(w, 'clue of $w')],
            level: 5,
            targetWords: s.targetWords,
          )!;
      checkPuzzle(p, s, englishAlphabet);
      expect(p.words.length, s.targetWords);
    }
  });

  test('words that contain each other are not both used', () {
    final p =
        WordSearchGenerator(
          size: 8,
          directions: const [WordDirection.across, WordDirection.down],
          random: Random(1),
        ).make(
          [
            for (final w in ['CAT', 'CATALOG', 'DOG', 'HORSE', 'MOUSE', 'BIRD'])
              WordCandidate(w, w),
          ],
          level: 1,
          targetWords: 5,
        )!;
    final listed = p.words.map((w) => w.word).toSet();
    expect(listed.contains('CAT') && listed.contains('CATALOG'), isFalse);
  });

  test('a puzzle survives saving and loading; drags either way find it', () {
    final p =
        WordSearchGenerator(
          size: 6,
          directions: const [WordDirection.across, WordDirection.down],
          random: Random(3),
        ).make(
          [
            for (final w in ['SUN', 'MOON', 'STAR', 'SKY', 'RAIN'])
              WordCandidate(w, 'about $w', 'για $w'),
          ],
          level: 1,
          targetWords: 5,
        )!;
    final back = WordSearchPuzzle.fromJson(p.toJson());
    expect(back.letters, p.letters);
    expect(back.signature, p.signature);
    final w = back.words.first;
    expect(w.clueTr, startsWith('για'));
    final (r0, c0) = w.cells.first;
    final (r1, c1) = w.cells.last;
    expect(back.wordAt(r0, c0, r1, c1)?.word, w.word);
    expect(back.wordAt(r1, c1, r0, c0)?.word, w.word);
    expect(back.wordAt(r0, c0, r0, c0), isNull);
  });

  for (final (lang, db, alphabet) in [
    ('English', 'en', englishAlphabet),
    ('Greek', 'el', greekAlphabet),
  ]) {
    test('$lang dictionary fills every kind of level', () {
      final pool = lang == 'Greek' ? poolSize(db) : null;
      for (final level in [1, 2, 3, 5, 7, 12]) {
        final s = WordSearchLevel.forLevel(level, poolSize: pool);
        final clock = Stopwatch()..start();
        final p = WordSearchGenerator(
          size: s.gridSize,
          directions: s.directions,
          alphabet: alphabet,
          random: Random(level),
        ).make(dbCandidates(db, s), level: level, targetWords: s.targetWords);
        expect(p, isNotNull, reason: '$lang level $level');
        checkPuzzle(p!, s, alphabet);
        print(
          '$lang L$level ${s.gridSize}×${s.gridSize}: '
          '${p.words.length}/${s.targetWords} words in '
          '${clock.elapsedMilliseconds} ms',
        );
      }
    });
  }
}
