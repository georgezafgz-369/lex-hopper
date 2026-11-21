// ─────────────────────────────────────────────────────────────────────────────
// CROSSWORD MAKER — builds a fresh puzzle for a level from the dictionary
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'crossword_puzzle.dart';
import 'dictionary_service.dart';
import 'puzzle_themes.dart';

class CrosswordMaker {
  CrosswordMaker._();

  static const _seenKey = 'crossword_seen_sets';
  static String _seenKeyFor(String language) =>
      language == 'el' ? '${_seenKey}_el' : _seenKey;
  static const _maxSeen = 1000;

  /// How long to look for a puzzle with every word of the level. Bigger
  /// levels rarely fit them all, so after this the best one found is used
  /// instead of searching on (which took several seconds per level).
  static const _searchTime = Duration(milliseconds: 1500);

  /// A new puzzle for [level], using words from the dictionary.
  /// Individual words may repeat across games, but never the exact same set
  /// of words: every set handed out is remembered and skipped next time.
  /// [language] "el" makes a Greek crossword (answers in capitals without
  /// accents, Greek clues) from the Greek dictionary.
  /// [theme] limits the answers to one subject (null: all subjects).
  static Future<CrosswordPuzzle> make(
    int level, {
    Random? random,
    String language = 'en',
    PuzzleTheme? theme,
  }) async {
    final service = DictionaryService.forLanguage(language);
    final settings = LevelSettings.forLevel(
      level,
      poolSize: language == 'el' ? await service.puzzlePoolSize() : null,
    );
    final prefs = await SharedPreferences.getInstance();
    final seenKey = _seenKeyFor(language);
    final seen = prefs.getStringList(seenKey) ?? <String>[];
    final generator = CrosswordGenerator(
      size: settings.gridSize,
      random: random,
    );

    CrosswordPuzzle? fallback;
    final clock = Stopwatch()..start();
    for (var tries = 0; tries < 8; tries++) {
      final left = _searchTime - clock.elapsed;
      if (fallback != null && left <= Duration.zero) break;
      final candidates = theme == null
          ? await service.puzzleCandidates(
              minLen: settings.minLen,
              maxLen: settings.maxLen,
              minRank: settings.minRank,
              maxRank: settings.maxRank,
              phrases: settings.phrases,
            )
          : await service.themeCandidates(
              theme: theme.id,
              level: level,
              minLen: settings.minLen,
              maxLen: settings.maxLen,
            );
      final entries = generator.layout(
        candidates,
        targetWords: settings.targetWords,
        minWords: min(3, settings.targetWords),
        // Always try at least a little, even when the time is up but
        // nothing usable has been found yet.
        timeLimit: left > const Duration(milliseconds: 300)
            ? left
            : const Duration(milliseconds: 300),
      );
      if (entries == null) continue;

      final puzzle = CrosswordPuzzle.fromEntries(
        level: level,
        size: settings.gridSize,
        entries: entries,
      );
      if (seen.contains(puzzle.signature)) continue;

      // Prefer a full puzzle; keep the best partial one in case none fills.
      if (entries.length >= settings.targetWords) {
        await _remember(prefs, seenKey, seen, puzzle.signature);
        return puzzle;
      }
      if (fallback == null || entries.length > fallback.entries.length) {
        fallback = puzzle;
      }
    }

    if (fallback == null) {
      throw StateError('Could not build a crossword for level $level');
    }
    await _remember(prefs, seenKey, seen, fallback.signature);
    return fallback;
  }

  static Future<void> _remember(
    SharedPreferences prefs,
    String seenKey,
    List<String> seen,
    String signature,
  ) async {
    final updated = [...seen, signature];
    if (updated.length > _maxSeen) {
      updated.removeRange(0, updated.length - _maxSeen);
    }
    await prefs.setStringList(seenKey, updated);
  }
}
