// ─────────────────────────────────────────────────────────────────────────────
// FIND THE WORDS MAKER — builds a fresh puzzle for a level from the dictionary
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'dictionary_service.dart';
import 'puzzle_themes.dart';
import 'word_search_puzzle.dart';

class WordSearchMaker {
  WordSearchMaker._();

  static String _seenKey(String language) => language == 'en'
      ? 'word_search_seen_sets'
      : 'word_search_seen_sets_$language';
  static const _maxSeen = 1000;

  /// How long to look for a puzzle holding every word of the level before
  /// using the fullest one found.
  static const _searchTime = Duration(milliseconds: 1500);

  /// A new puzzle for [level] in [language] ("en" or "el": Greek capitals
  /// without accents). Words may repeat across games, but never the exact
  /// same set of words.
  static Future<WordSearchPuzzle> make(
    int level, {
    String language = 'en',
    Random? random,
    PuzzleTheme? theme,
  }) async {
    final service = DictionaryService.forLanguage(language);
    final settings = WordSearchLevel.forLevel(
      level,
      // Every dictionary but the big English one: sized to its answers.
      poolSize: language == 'en' ? null : await service.puzzlePoolSize(),
    );
    final prefs = await SharedPreferences.getInstance();
    final seenKey = _seenKey(language);
    final seen = prefs.getStringList(seenKey) ?? <String>[];
    final generator = WordSearchGenerator(
      size: settings.gridSize,
      directions: settings.directions,
      alphabet: alphabetFor(language),
      random: random,
    );

    WordSearchPuzzle? fallback;
    final clock = Stopwatch()..start();
    for (var tries = 0; tries < 8; tries++) {
      if (fallback != null && clock.elapsed > _searchTime) break;
      final candidates = theme == null
          ? await service.puzzleCandidates(
              minLen: settings.minLen,
              maxLen: settings.maxLen,
              minRank: settings.minRank,
              maxRank: settings.maxRank,
            )
          : await service.themeCandidates(
              theme: theme.id,
              level: level,
              minLen: settings.minLen,
              maxLen: settings.maxLen,
            );
      final puzzle = generator.make(
        candidates,
        level: level,
        targetWords: settings.targetWords,
        minWords: min(3, settings.targetWords),
      );
      if (puzzle == null || seen.contains(puzzle.signature)) continue;
      if (puzzle.words.length >= settings.targetWords) {
        await _remember(prefs, seenKey, seen, puzzle.signature);
        return puzzle;
      }
      if (fallback == null || puzzle.words.length > fallback.words.length) {
        fallback = puzzle;
      }
    }
    if (fallback == null) {
      throw StateError('Could not build a word search for level $level');
    }
    await _remember(prefs, seenKey, seen, fallback.signature);
    return fallback;
  }

  static Future<void> _remember(
    SharedPreferences prefs,
    String key,
    List<String> seen,
    String signature,
  ) async {
    final updated = [...seen, signature];
    if (updated.length > _maxSeen) {
      updated.removeRange(0, updated.length - _maxSeen);
    }
    await prefs.setStringList(key, updated);
  }
}
