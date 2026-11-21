// ─────────────────────────────────────────────────────────────────────────────
// SAVED TRANSLATIONS — the Translator's memory, on this phone only
//
// Every text the phone's translator translates (a sentence, or a word the
// lexicon doesn't have) is kept here once the person is done with it, so the
// same text is answered at once next time, offline. Kept in my_texts.db in
// the app's own folder; it never leaves the phone. At most [limit] texts:
// the ones used longest ago make room for new ones.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// The memory the Translator talks to (tests give it an in-memory one).
abstract class SavedTranslations {
  /// The saved translation of [text] from [from] into [to], or null.
  Future<String?> find(String text, {required String from, required String to});

  /// Keeps [translation] of [text] (replacing an older one).
  Future<void> save(
    String text,
    String translation, {
    required String from,
    required String to,
  });

  /// How many texts are saved.
  Future<int> count();

  /// Forgets every saved text.
  Future<void> clear();
}

/// The same text however it's spaced or capitalised: "  Good   Morning " and
/// "good morning" are one text.
String savedKey(String text) =>
    text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class PhoneSavedTranslations implements SavedTranslations {
  PhoneSavedTranslations._();
  static final instance = PhoneSavedTranslations._();

  /// How many texts are kept at most.
  static const limit = 5000;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> _open() => _opening ??= () async {
    final dir = (await getApplicationDocumentsDirectory()).path;
    await Directory(dir).create(recursive: true);
    return _db = await openDatabase(
      p.join(dir, 'my_texts.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE saved (
          from_lang TEXT NOT NULL, to_lang TEXT NOT NULL,
          key TEXT NOT NULL, text TEXT NOT NULL, translation TEXT NOT NULL,
          used INTEGER NOT NULL,
          PRIMARY KEY (from_lang, to_lang, key))
      '''),
    );
  }();

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<String?> find(
    String text, {
    required String from,
    required String to,
  }) async {
    final db = await _open();
    final key = savedKey(text);
    final rows = await db.query(
      'saved',
      columns: ['translation'],
      where: 'from_lang = ? AND to_lang = ? AND key = ?',
      whereArgs: [from, to, key],
    );
    if (rows.isEmpty) return null;
    // Used again: it stays among the ones kept.
    await db.update(
      'saved',
      {'used': _now},
      where: 'from_lang = ? AND to_lang = ? AND key = ?',
      whereArgs: [from, to, key],
    );
    return rows.first['translation'] as String;
  }

  @override
  Future<void> save(
    String text,
    String translation, {
    required String from,
    required String to,
  }) async {
    if (text.trim().isEmpty || translation.trim().isEmpty) return;
    final db = await _open();
    await db.insert('saved', {
      'from_lang': from,
      'to_lang': to,
      'key': savedKey(text),
      'text': text.trim(),
      'translation': translation.trim(),
      'used': _now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    // Keep at most [limit]: drop the ones used longest ago.
    await db.execute(
      'DELETE FROM saved WHERE rowid IN (SELECT rowid FROM saved '
      'ORDER BY used DESC LIMIT -1 OFFSET ?)',
      [limit],
    );
  }

  @override
  Future<int> count() async {
    final db = await _open();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT count(*) FROM saved'),
        ) ??
        0;
  }

  @override
  Future<void> clear() async {
    final db = await _open();
    await db.delete('saved');
  }

  /// Closes the database (tests).
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _opening = null;
  }
}

/// An in-memory memory, for tests.
class MemorySavedTranslations implements SavedTranslations {
  final Map<String, String> _saved = {};
  String _k(String text, String from, String to) =>
      '$from>$to:${savedKey(text)}';

  @override
  Future<String?> find(
    String text, {
    required String from,
    required String to,
  }) async => _saved[_k(text, from, to)];

  @override
  Future<void> save(
    String text,
    String translation, {
    required String from,
    required String to,
  }) async {
    if (text.trim().isEmpty || translation.trim().isEmpty) return;
    _saved[_k(text, from, to)] = translation.trim();
  }

  @override
  Future<int> count() async => _saved.length;

  @override
  Future<void> clear() async => _saved.clear();
}
