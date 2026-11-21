// ─────────────────────────────────────────────────────────────────────────────
// FIND THE WORDS SAVE — one saved game per language
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'puzzle_themes.dart';
import 'word_search_puzzle.dart';

/// A saved Find the Words game: the puzzle and the words found so far
/// (with the tint each was marked in).
class WordSearchProgress {
  final WordSearchPuzzle puzzle;
  final Map<String, int> found;

  /// The subject chosen at New Game (null: all subjects).
  final PuzzleTheme? theme;

  const WordSearchProgress(this.puzzle, this.found, [this.theme]);

  Map<String, dynamic> toJson() => {
    'puzzle': puzzle.toJson(),
    'found': found,
    if (theme != null) 'theme': theme!.id,
  };

  factory WordSearchProgress.fromJson(Map<String, dynamic> json) =>
      WordSearchProgress(
        WordSearchPuzzle.fromJson(json['puzzle'] as Map<String, dynamic>),
        {
          for (final e in (json['found'] as Map).entries)
            e.key as String: e.value as int,
        },
        PuzzleTheme.byId(json['theme'] as String?),
      );
}

/// An English game and a Greek game are kept apart; each language's menu
/// continues its own. [language] defaults to the app's current language.
class WordSearchSave {
  WordSearchSave._();

  static String _key(String? language) =>
      (language ?? AppSettings.instance.languageCode) == 'el'
      ? 'word_search_save_el'
      : 'word_search_save';

  static Future<void> save(
    WordSearchProgress progress, {
    String? language,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(language), jsonEncode(progress.toJson()));
  }

  static Future<WordSearchProgress?> load({String? language}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(language));
    if (raw == null || raw.isEmpty) return null;
    try {
      return WordSearchProgress.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw)),
      );
    } catch (_) {
      return null; // an unreadable save counts as none
    }
  }

  static Future<void> clear({String? language}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(language));
  }
}
