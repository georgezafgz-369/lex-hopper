// ─────────────────────────────────────────────────────────────────────────────
// CROSSWORD SAVE MANAGER
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// One saved crossword per language: an English game and a Greek game are
/// kept apart, and each language's menu continues its own. [language]
/// defaults to the app's current language.
class CrosswordSave {
  CrosswordSave._();

  static String _key(String? language) =>
      (language ?? AppSettings.instance.languageCode) == 'el'
      ? 'crossword_save_el'
      : 'crossword_save';

  static Future<void> save(
    Map<String, dynamic> state, {
    String? language,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(language), jsonEncode(state));
  }

  static Future<Map<String, dynamic>?> load({String? language}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(language));
    if (raw == null || raw.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(raw));
  }

  static Future<void> clear({String? language}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(language));
  }
}
