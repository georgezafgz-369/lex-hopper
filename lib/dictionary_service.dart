// ─────────────────────────────────────────────────────────────────────────────
// DICTIONARY SERVICE — reads Lex Hopper's two databases (lexicon.db: words
// and short phrases; texts.db: meanings, examples, clues, long phrases)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'puzzle_themes.dart' show themeWindow;
import 'crossword_puzzle.dart' show WordCandidate, phraseGap;

/// A single dictionary entry.
class DictionaryEntry {
  final int id;
  final String word;
  final String partOfSpeech;
  final String meaning;
  final String domain;
  final String source;

  /// Subject label id (e.g. "law"), or null for General.
  final String? subject;

  /// Usage label ids (e.g. ["vulgar", "slang"]), most significant first.
  final List<String> usages;

  /// "simple", "compound" or "derived" (null for non-alphabetic words).
  final String? structure;

  /// Other words with exactly this meaning (one form of each).
  final List<String> synonyms;

  /// Source language for loanwords when known, e.g. "Yiddish".
  final String? origin;

  /// Example sentences from WordNet ("he gave his word").
  final List<String> examples;

  /// Opposite words (hard -> easy).
  final List<String> antonyms;

  /// Other forms of the same word (word -> wording).
  final List<String> related;

  /// 1 = most common meaning of this word and part of speech; null when
  /// unknown (medical entries, inflected forms).
  final int? sense;

  /// Diagnosis code for medical terms, e.g. "ICD-10 A00.0".
  final String? code;

  /// Medical category, e.g. "Disease" or "Anatomy" (null for other words).
  final String? category;

  /// The other name the search matched, when the entry was found through
  /// an alias ("abdominal bloating" finds "abdominal distention").
  final String? matchedAlias;

  /// In the A–Z list (one card per word): how many meanings the word has
  /// (that match the filters). Null in search results.
  final int? meaningCount;

  DictionaryEntry({
    required this.id,
    required this.word,
    required this.partOfSpeech,
    required this.meaning,
    required this.domain,
    required this.source,
    this.subject,
    this.usages = const [],
    this.structure,
    this.synonyms = const [],
    this.origin,
    this.examples = const [],
    this.antonyms = const [],
    this.related = const [],
    this.sense,
    this.code,
    this.category,
    this.matchedAlias,
    this.meaningCount,
  });

  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      id: map['id'] as int,
      word: map['word'] as String,
      partOfSpeech: map['pos'] as String,
      meaning: map['meaning'] as String,
      domain: map['domain'] as String,
      source: map['source'] as String,
      subject: map['subject'] as String?,
      usages: (map['usage'] as String?)?.split(',') ?? const [],
      structure: map['structure'] as String?,
      synonyms: (map['synonyms'] as String?)?.split(',') ?? const [],
      origin: map['origin'] as String?,
      examples: (map['examples'] as String?)?.split('\n') ?? const [],
      antonyms: (map['antonyms'] as String?)?.split(',') ?? const [],
      related: (map['related'] as String?)?.split(',') ?? const [],
      sense: map['sense'] as int?,
      code: map['code'] as String?,
      category: map['category'] as String?,
      matchedAlias: map['matched_alias'] as String?,
      meaningCount: map['meaning_count'] as int?,
    );
  }

  /// A short preview of the meaning (first ~120 characters).
  String get preview {
    const maxLen = 120;
    if (meaning.length <= maxLen) return meaning;
    return '${meaning.substring(0, maxLen)}.…';
  }
}

/// Part-of-speech ids in display order, with their full names.
const partOfSpeechNames = {
  'noun': 'Noun',
  'verb': 'Verb',
  'adj': 'Adjective',
  'adv': 'Adverb',
  'pron': 'Pronoun',
  'prep': 'Preposition',
  'conj': 'Conjunction',
  'interj': 'Interjection',
  'det': 'Determiner',
  // Greek only:
  'art': 'Article',
  'part': 'Participle',
};

final partOfSpeechOrder = partOfSpeechNames.keys.toList();

/// Full name for a part-of-speech id, e.g. "adj" -> "Adjective".
String partOfSpeechName(String pos) =>
    partOfSpeechNames[pos] ?? pos.toUpperCase();

/// One meaning of a word in the other language, from the lexicon's links
/// (data/lexicon/links.csv): σπίτι (noun) -> home, place.
class WordTranslation {
  final String pos;
  final List<String> words;
  const WordTranslation(this.pos, this.words);
}

/// The word shown on the home page today: its dictionary entry, and its
/// translation into the other app language when the dictionary has one.
class WordOfTheDay {
  final DictionaryEntry entry;
  final String? translation;
  const WordOfTheDay(this.entry, this.translation);
}

class WordInfo {
  /// American pronunciation in IPA, e.g. "ˈdɪkʃəˌnɛri" (CMU dictionary).
  final String? ipa;
  final int? syllables;

  /// Adjectives meaning "relating to" this word (tooth -> dental).
  final List<String> adjectives;

  /// Forms per part of speech, e.g. {'noun': 'dictionaries',
  /// 'verb': 'begins, began, begun, beginning'}.
  final Map<String, String> forms;

  const WordInfo({
    this.ipa,
    this.syllables,
    this.adjectives = const [],
    this.forms = const {},
  });
}

/// A subject or usage label. Names are stored per language code so other
/// languages can be added to dictionary_filters.json later.
class DictionaryLabel {
  final String id;
  final Map<String, String> names;
  final Map<String, String> descriptions;
  final int count; // how many entries carry this label

  const DictionaryLabel({
    required this.id,
    required this.names,
    this.descriptions = const {},
    this.count = 0,
  });

  /// Display name; falls back to English.
  String name([String lang = 'en']) => names[lang] ?? names['en'] ?? id;

  /// Short explanation, e.g. "Two words joined (bookshop)"; may be empty.
  String description([String lang = 'en']) =>
      descriptions[lang] ?? descriptions['en'] ?? '';

  factory DictionaryLabel.fromJson(Map<String, dynamic> json) =>
      DictionaryLabel(
        id: json['id'] as String,
        names: Map<String, String>.from(json['names'] as Map),
        descriptions: Map<String, String>.from(
          (json['descriptions'] as Map?) ?? {},
        ),
        count: (json['count'] as int?) ?? 0,
      );
}

/// One of the 8 subject groups, e.g. "Natural Sciences".
class SubjectGroup {
  final DictionaryLabel label;
  final List<DictionaryLabel> subjects;

  const SubjectGroup({required this.label, required this.subjects});

  factory SubjectGroup.fromJson(Map<String, dynamic> json) => SubjectGroup(
    label: DictionaryLabel.fromJson(json),
    subjects: (json['subjects'] as List)
        .map((s) => DictionaryLabel.fromJson(Map<String, dynamic>.from(s)))
        .toList(),
  );
}

/// Available filter options, loaded from the bundled JSON.
class FilterOptions {
  final List<String> partOfSpeech;
  final List<SubjectGroup> subjectGroups;
  final List<DictionaryLabel> usageLabels;

  /// Word structure: simple / compound / derived.
  final List<DictionaryLabel> structures;

  FilterOptions({
    required this.partOfSpeech,
    required this.subjectGroups,
    required this.usageLabels,
    this.structures = const [],
  });

  /// Every subject across all groups, by id.
  late final Map<String, DictionaryLabel> subjectsById = {
    for (final g in subjectGroups)
      for (final s in g.subjects) s.id: s,
  };

  late final Map<String, DictionaryLabel> usageById = {
    for (final u in usageLabels) u.id: u,
  };

  factory FilterOptions.fromJson(Map<String, dynamic> map) => FilterOptions(
    partOfSpeech: List<String>.from(map['partOfSpeech'] ?? []),
    subjectGroups: (map['subjectGroups'] as List? ?? [])
        .map((g) => SubjectGroup.fromJson(Map<String, dynamic>.from(g)))
        .toList(),
    usageLabels: (map['usageLabels'] as List? ?? [])
        .map((u) => DictionaryLabel.fromJson(Map<String, dynamic>.from(u)))
        .toList(),
    structures: (map['structures'] as List? ?? [])
        .map((u) => DictionaryLabel.fromJson(Map<String, dynamic>.from(u)))
        .toList(),
  );

  static Future<FilterOptions> load() async {
    final raw = await rootBundle.loadString('assets/dictionary_filters.json');
    return FilterOptions.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}

/// The word in small letters without accents or diaeresis, final ς as σ
/// (Σπίτι -> σπιτι). The Greek dictionary stores every word this way too
/// (`plain`, see scripts/build_greek_dictionary.py), so a search finds the
/// word whether or not the user types its accents.
String greekPlain(String text) {
  const marks = {
    'ά': 'α',
    'έ': 'ε',
    'ή': 'η',
    'ί': 'ι',
    'ό': 'ο',
    'ύ': 'υ',
    'ώ': 'ω',
    'ϊ': 'ι',
    'ϋ': 'υ',
    'ΐ': 'ι',
    'ΰ': 'υ',
    'ς': 'σ',
  };
  return text.toLowerCase().split('').map((c) => marks[c] ?? c).join();
}

/// The dictionary service: one per dictionary language, both reading the
/// same two databases built from data/lexicon and data/texts
/// (scripts/build_databases.py):
///  * assets/lexicon.db — every word and short phrase of both languages,
///    the links between their meanings and their main translations;
///  * assets/texts.db — the meanings, example sentences, crossword clues and
///    long phrases (4+ words), each with its translation.
/// [english] and [greek] see only their own language.
class DictionaryService {
  DictionaryService._(this.language);

  /// "en" or "el".
  final String language;

  static final DictionaryService english = DictionaryService._('en');
  static final DictionaryService greek = DictionaryService._('el');

  /// The English dictionary (kept for older code).
  static DictionaryService get instance => english;

  /// The dictionary for an app language code ("el" -> Greek, else English).
  static DictionaryService forLanguage(String code) =>
      code == 'el' ? greek : english;

  /// The bundled databases.
  static const lexiconAsset = 'assets/lexicon.db';
  static const textsAsset = 'assets/texts.db';

  /// The databases' fingerprints, written by scripts/build_databases.py: a
  /// copy on the phone is named after its database's fingerprint, so a
  /// changed database is copied again without anything to remember.
  static const versionsAsset = 'assets/databases.json';

  /// The old dictionaries' copies (before lexicon.db and texts.db), deleted
  /// to free the space.
  static final _oldFiles = [
    'dictionary.db',
    for (var v = 2; v <= 25; v++) 'dictionary_v$v.db',
    for (var v = 1; v <= 22; v++) 'dictionary_el_v$v.db',
  ];

  bool get _isGreek => language == 'el';

  /// The search key of a word: lowercase; Greek also without accents.
  String _key(String text) => _isGreek ? greekPlain(text) : text.toLowerCase();

  /// Words that start with a letter (the rest are listed after the last
  /// letter of the alphabet).
  String get _letterGlob =>
      _isGreek ? "plain GLOB '[α-ω]*'" : "plain GLOB '[a-z]*'";

  Database? _db;
  Future<void>? _opening;

  /// Open the databases (copying them out of the app on first run).
  Future<void> init() => _opening ??= _open();

  static Future<(String, String)>? _copying;

  Future<void> _open() async {
    final (lexicon, texts) = await (_copying ??= _copyDatabases());
    final db = await openDatabase(lexicon, readOnly: true);
    await db.execute('ATTACH DATABASE ? AS t', [texts]);
    // Lets "word LIKE 'ab%'" use the index (keys are already lowercase).
    await db.execute('PRAGMA case_sensitive_like = ON');
    await db.execute(_dictView(language));
    _db = db;
  }

  /// `dict`: every meaning of this language — words and short phrases from
  /// the lexicon, long phrases from the texts — with its meaning and example
  /// sentences as text, in the columns [DictionaryEntry.fromMap] reads.
  static String _dictView(String lang) {
    String examples(String id) =>
        '(SELECT group_concat(text, char(10)) FROM (SELECT tx.text '
        'FROM entry_examples x JOIN t.texts tx ON tx.id = x.text_id '
        'WHERE x.entry_id = $id ORDER BY x.ord))';
    const cols =
        'sense, synonyms, antonyms, related, origin, category, subject, '
        'usage, structure, code, domain, source';
    String prefixed(String x) =>
        cols.split(', ').map((c) => '$x.$c').join(', ');
    return 'CREATE TEMP VIEW IF NOT EXISTS dict AS '
        'SELECT e.id, e.word, e.plain, e.type, e.pos, m.text AS meaning, '
        '${examples('e.id')} AS examples, ${prefixed('e')} '
        'FROM main.entries e JOIN t.texts m ON m.id = e.meaning_id '
        "WHERE e.lang = '$lang' "
        'UNION ALL '
        'SELECT p.id, p.phrase, p.plain, p.type, p.pos, m.text, '
        '${examples('p.id')}, ${prefixed('p')} '
        'FROM t.phrases p JOIN t.texts m ON m.id = p.meaning_id '
        "WHERE p.lang = '$lang'";
  }

  static Future<(String, String)> _copyDatabases() async {
    final dir = await _databaseDir();
    await Directory(dir).create(recursive: true);
    final versions = jsonDecode(
      await rootBundle.loadString(versionsAsset),
    ) as Map<String, dynamic>;
    final lexiconFile = 'lexicon_${versions['lexicon']}.db';
    final textsFile = 'texts_${versions['texts']}.db';
    // Free the space of the old dictionaries and of earlier copies.
    for (final name in _oldFiles) {
      final old = File(p.join(dir, name));
      if (await old.exists()) await old.delete();
    }
    await for (final f in Directory(dir).list()) {
      final name = p.basename(f.path);
      final ours = RegExp(r'^(lexicon|texts)_.*\.db(\.part)?$');
      if (f is File &&
          ours.hasMatch(name) &&
          name != lexiconFile &&
          name != textsFile) {
        await f.delete();
      }
    }
    Future<String> copy(String asset, String name) async {
      final file = File(p.join(dir, name));
      if (!await file.exists()) {
        final raw = await rootBundle.load(asset);
        // Written under another name first, so a copy cut short (app
        // closed) is never taken for a whole one.
        final part = File('${file.path}.part');
        await part.writeAsBytes(
          raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
          flush: true,
        );
        await part.rename(file.path);
      }
      return file.path;
    }

    return (
      await copy(lexiconAsset, lexiconFile),
      await copy(textsAsset, textsFile),
    );
  }

  static Future<String> _databaseDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return (await getApplicationDocumentsDirectory()).path;
    }
    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '.';
      return p.join(home, 'Library', 'Application Support', 'lex_hopper');
    } else if (Platform.isWindows) {
      return p.join(Platform.environment['APPDATA'] ?? '.', 'lex_hopper');
    } else if (Platform.isLinux) {
      final configHome =
          Platform.environment['XDG_CONFIG_HOME'] ??
          p.join(Platform.environment['HOME'] ?? '.', '.config');
      return p.join(configHome, 'lex_hopper');
    }
    return p.join(Directory.systemTemp.path, 'lex_hopper');
  }

  /// Full rows from `dict` for [ids], in the order of [ids].
  Future<List<Map<String, Object?>>> _rows(
    List<int> ids, {
    String filters = '',
    List<Object?> args = const [],
  }) async {
    if (ids.isEmpty) return const [];
    final rows = await _db!.rawQuery(
      'SELECT * FROM dict WHERE id IN '
      '(${List.filled(ids.length, '?').join(',')})$filters',
      [...ids, ...args],
    );
    final byId = {for (final r in rows) r['id'] as int: r};
    return [
      for (final i in ids)
        if (byId[i] != null) byId[i]!,
    ];
  }

  /// Filter conditions on the label columns, as " AND …" plus its values.
  (String, List<Object?>) _filters({
    String? partOfSpeech,
    String? subject,
    String? usage,
    String? structure,
  }) {
    final conditions = <String>[];
    final args = <Object?>[];
    if (partOfSpeech != null && partOfSpeech.isNotEmpty) {
      conditions.add('pos = ?');
      args.add(partOfSpeech);
    }
    if (subject == generalSubject) {
      conditions.add('subject IS NULL');
    } else if (subject != null && subject.isNotEmpty) {
      conditions.add('subject = ?');
      args.add(subject);
    }
    if (usage != null && usage.isNotEmpty) {
      // usage holds several ids, e.g. "vulgar,slang"
      conditions.add("(',' || ifnull(usage, '') || ',') LIKE ?");
      args.add('%,$usage,%');
    }
    if (structure != null && structure.isNotEmpty) {
      conditions.add('structure = ?');
      args.add(structure);
    }
    return (conditions.map((c) => ' AND $c').join(), args);
  }

  /// `SELECT … FROM` both word tables of this language (lexicon entries and
  /// long phrases), with the same column names: id, word, plain, pos, sense,
  /// subject, usage, structure, category, domain.
  String get _allWords =>
      '(SELECT id, word, plain, pos, sense, subject, usage, structure, '
      'category, domain FROM main.entries WHERE lang = \'$language\' '
      'UNION ALL SELECT id, phrase, plain, pos, sense, subject, usage, '
      'structure, category, domain FROM t.phrases '
      'WHERE lang = \'$language\')';

  /// Subject filter value meaning "words with no subject".
  static const generalSubject = 'general';

  /// Search for words starting with [query] (may be empty when a filter is
  /// set). Optional filters: part of speech, subject id (or [generalSubject]),
  /// and usage label id.
  Future<List<DictionaryEntry>> search({
    required String query,
    String? partOfSpeech,
    String? subject,
    String? usage,
    String? structure,
    int limit = 100,
  }) async {
    await init();
    final db = _db!;
    final (filters, args) = _filters(
      partOfSpeech: partOfSpeech,
      subject: subject,
      usage: usage,
      structure: structure,
    );
    // Words that START with the query ("_" matches any one letter, so the
    // crossword pattern "p__y" finds "pity", "play", …), plus entries whose
    // other names (aliases) start with it. Shortest first in each.
    final pattern = '${_key(query)}%';
    final byWord = await db.rawQuery(
      'SELECT id FROM (SELECT id, word AS w FROM main.entries '
      "WHERE lang = '$language' AND plain LIKE ?$filters "
      'UNION ALL SELECT id, phrase FROM t.phrases '
      "WHERE lang = '$language' AND plain LIKE ?$filters) "
      'ORDER BY length(w), w LIMIT ?',
      [pattern, ...args, pattern, ...args, limit],
    );
    final rows = <Map<String, Object?>>[
      ...await _rows([for (final r in byWord) r['id'] as int]),
    ];
    if (query.isNotEmpty) {
      final byAlias = await db.rawQuery(
        'SELECT entry_id, alias FROM aliases WHERE lang = ? AND plain LIKE ? '
        'ORDER BY length(alias), alias LIMIT ?',
        [language, pattern, limit],
      );
      final alias = {
        for (final r in byAlias.reversed)
          r['entry_id'] as int: r['alias'] as String,
      };
      final found = await _rows(
        alias.keys.toList(),
        filters: filters,
        args: args,
      );
      rows.addAll([
        for (final r in found) {...r, 'matched_alias': alias[r['id']]},
      ]);
    }

    // Merge, one card per entry, ordered by the text that matched.
    final seen = <int>{};
    final merged = [
      for (final row in rows)
        if (seen.add(row['id'] as int)) DictionaryEntry.fromMap(row),
    ];
    String shown(DictionaryEntry e) => e.matchedAlias ?? e.word;
    merged.sort((a, b) {
      final byLength = shown(a).length.compareTo(shown(b).length);
      return byLength != 0 ? byLength : shown(a).compareTo(shown(b));
    });
    return merged.take(limit).toList();
  }

  /// Other names for each of [ids] ("abdominal bloating" for
  /// "abdominal distention"), for the word page's "Also called".
  Future<Map<int, List<String>>> aliasesFor(Iterable<int> ids) async {
    await init();
    if (ids.isEmpty) return {};
    final list = ids.toList();
    final rows = await _db!.rawQuery(
      'SELECT entry_id, alias FROM aliases WHERE entry_id IN '
      '(${List.filled(list.length, '?').join(',')}) ORDER BY alias',
      list,
    );
    final out = <int, List<String>>{};
    for (final r in rows) {
      out.putIfAbsent(r['entry_id'] as int, () => []).add(r['alias'] as String);
    }
    return out;
  }

  /// Pronunciation, syllables, forms and linked adjectives for [word].
  Future<WordInfo> wordInfo(String word) async {
    await init();
    final info = await _db!.rawQuery(
      'SELECT ipa, syllables, adjectives FROM word_info '
      'WHERE lang = ? AND word = ?',
      [language, word],
    );
    final forms = await _db!.rawQuery(
      'SELECT pos, forms FROM word_forms WHERE lang = ? AND word = ?',
      [language, word],
    );
    final row = info.isEmpty ? null : info.first;
    return WordInfo(
      ipa: row?['ipa'] as String?,
      syllables: row?['syllables'] as int?,
      adjectives: (row?['adjectives'] as String?)?.split(',') ?? const [],
      forms: {for (final f in forms) f['pos'] as String: f['forms'] as String},
    );
  }

  /// Extra example sentences for [word].
  Future<List<String>> moreExamples(String word) async {
    await init();
    final rows = await _db!.rawQuery(
      'SELECT tx.text FROM word_examples w JOIN t.texts tx '
      'ON tx.id = w.text_id WHERE w.lang = ? AND w.word = ?',
      [language, word],
    );
    return [for (final r in rows) r['text'] as String];
  }

  /// Part of speech in display order, as an SQL CASE.
  static String get _posRank => partOfSpeechOrder
      .asMap()
      .entries
      .map((e) => "WHEN '${e.value}' THEN ${e.key}")
      .join(' ');

  /// The whole dictionary A–Z, one entry per word (its most common meaning,
  /// with [DictionaryEntry.meaningCount]), for an empty search. Words that
  /// start with a letter come first; with [symbols] true, the ones starting
  /// with a number or symbol (listed after Z). Pages through with [after]:
  /// pass the last word of the previous page.
  Future<List<DictionaryEntry>> browse({
    String after = '',
    bool symbols = false,
    String? partOfSpeech,
    String? subject,
    String? structure,
    int limit = 100,
  }) async {
    await init();
    final (filters, args) = _filters(
      partOfSpeech: partOfSpeech,
      subject: subject,
      structure: structure,
    );
    final glob = symbols ? 'NOT $_letterGlob' : _letterGlob;
    // The next words in order (accent-free order, then the word itself),
    // from each table on its own (each in index order: fast), merged.
    final key = _key(after);
    Future<List<Map<String, Object?>>> next(String table, String word) =>
        _db!.rawQuery(
          'SELECT DISTINCT plain, $word AS word FROM $table '
          'WHERE lang = ? AND $glob AND plain >= ? '
          'AND (plain, $word) > (?, ?)$filters '
          'ORDER BY plain, $word LIMIT ?',
          [language, key, key, after, ...args, limit],
        );
    final words = [
      ...await next('main.entries', 'word'),
      ...await next('t.phrases', 'phrase'),
    ];
    if (words.isEmpty) return const [];
    int order(Map<String, Object?> a, Map<String, Object?> b) {
      final c = (a['plain'] as String).compareTo(b['plain'] as String);
      return c != 0 ? c : (a['word'] as String).compareTo(b['word'] as String);
    }

    words.sort(order);
    final names = <String>[];
    for (final w in words) {
      final name = w['word'] as String;
      if (names.isEmpty || names.last != name) names.add(name);
      if (names.length == limit) break;
    }
    // …and each one's meanings: the card shows the first part of speech in
    // display order, then its most common meaning.
    final meanings = await _db!.rawQuery(
      'SELECT id, word, (CASE pos $_posRank ELSE 99 END) * 100000 + '
      'ifnull(sense, 99999) AS first FROM $_allWords WHERE word IN '
      '(${List.filled(names.length, '?').join(',')})$filters',
      [...names, ...args],
    );
    final best = <String, (int, int)>{};
    final count = <String, int>{};
    for (final m in meanings) {
      final w = m['word'] as String;
      count[w] = (count[w] ?? 0) + 1;
      final first = m['first'] as int;
      final id = m['id'] as int;
      final b = best[w];
      if (b == null || first < b.$1 || (first == b.$1 && id < b.$2)) {
        best[w] = (first, id);
      }
    }
    final rows = await _rows([
      for (final w in names)
        if (best[w] != null) best[w]!.$2,
    ]);
    return [
      for (final r in rows)
        DictionaryEntry.fromMap({...r, 'meaning_count': count[r['word']]}),
    ];
  }

  /// Every entry for exactly [word], grouped by part of speech in display
  /// order (noun, verb, adjective…), for the word page.
  Future<List<DictionaryEntry>> entriesFor(String word) async {
    await init();
    Future<List<Map<String, Object?>>> exactly(String w) => _db!.rawQuery(
      'SELECT * FROM dict WHERE plain = ? AND word = ? '
      // Most common meaning first; unranked (medical) entries last.
      'ORDER BY CASE pos $_posRank ELSE 99 END, sense IS NULL, sense, id',
      [_key(w), w],
    );
    var rows = await exactly(word);
    // A word asked for in other letters (crossword answers: ΣΠΙΤΙ, APPLE):
    // the word spelled that way. The first match by search key wins.
    if (rows.isEmpty) {
      final match = await _db!.rawQuery(
        'SELECT word FROM $_allWords WHERE plain = ? '
        'ORDER BY sense IS NULL, sense, id LIMIT 1',
        [_key(word)],
      );
      if (match.isNotEmpty) rows = await exactly(match.first['word'] as String);
    }
    return rows.map(DictionaryEntry.fromMap).toList();
  }

  /// Multi-word entries that contain [word] as a whole word ("in a word",
  /// "word of mouth"), one entry per phrase, shortest first.
  Future<List<DictionaryEntry>> phrasesWith(
    String word, {
    int limit = 40,
  }) async {
    await init();
    if (word.contains(' ')) return [];
    final key = _key(word);
    // The everyday multi-word entries with this word, found through
    // `phrase_words` (each word of a phrase -> the phrase), from each table
    // on its own, merged.
    Future<List<Map<String, Object?>>> find(String table, String w) =>
        _db!.rawQuery(
          'SELECT min(x.id) AS id, x.$w AS word, '
          "max(ifnull(x.category, '') IN ('Idiom', 'Phrasal verb', "
          "'Proverb')) AS special, min(x.domain = 'medical') AS medical "
          'FROM phrase_words pw JOIN $table x ON x.id = pw.entry_id '
          'WHERE pw.lang = ? AND pw.word = ? GROUP BY x.$w',
          [language, key],
        );
    final found = [
      ...await find('main.entries', 'word'),
      ...await find('t.phrases', 'phrase'),
    ];
    // Idioms, phrasal verbs and proverbs first, then other everyday
    // multi-word entries (word order, word game…), then medical ones;
    // shortest first within each.
    found.sort((a, b) {
      for (final c in [
        (b['special'] as int).compareTo(a['special'] as int),
        (a['medical'] as int).compareTo(b['medical'] as int),
        (a['word'] as String).length.compareTo((b['word'] as String).length),
        (a['word'] as String).compareTo(b['word'] as String),
      ]) {
        if (c != 0) return c;
      }
      return 0;
    });
    final rows = await _rows([
      for (final r in found.take(limit)) r['id'] as int,
    ]);
    return rows.map(DictionaryEntry.fromMap).toList();
  }

  /// The word of the day for [day]: a crossword answer of medium rarity
  /// (interesting, not obscure), picked from the date so it is the same all
  /// day, with the main meaning of its everyday sense. Null when none fits.
  Future<WordOfTheDay?> wordOfTheDay(DateTime day) async {
    await init();
    final (minRank, maxRank) = _isGreek ? (1500, 7000) : (3000, 15000);
    final rows = await _db!.rawQuery(
      'SELECT word, word_tr FROM puzzle_words WHERE lang = ? AND phrase = 0 '
      'AND len BETWEEN 5 AND 12 AND rank BETWEEN ? AND ? ORDER BY rank',
      [language, minRank, maxRank],
    );
    if (rows.isEmpty) return null;
    final dayNumber = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(2024)).inDays.abs();
    // Step through the list by a large prime so that consecutive days land
    // far apart; skip words without a plain, general first meaning. Retries
    // take small steps from the day's own spot, so they never land on the
    // next day's word (which would show the same word two days running).
    for (var i = 0; i < 30; i++) {
      final row = rows[(dayNumber * 7919 + i * 31) % rows.length];
      final entries = await entriesFor(row['word'] as String);
      for (final e in entries) {
        if (e.sense == 1 &&
            e.subject == null &&
            e.domain != 'medical' &&
            e.meaning.trim().isNotEmpty) {
          return WordOfTheDay(e, row['word_tr'] as String?);
        }
      }
    }
    return null;
  }

  /// The main translation of [text] (a word or phrase) into the other
  /// language, from the lexicon; null when the lexicon doesn't have it.
  Future<String?> mainTranslation(String text) async {
    await init();
    final word = text.trim();
    if (word.isEmpty) return null;
    final rows = await _db!.rawQuery(
      'SELECT translation FROM translations WHERE lang = ? AND plain = ? '
      'ORDER BY (word = ?) DESC LIMIT 1',
      [language, _key(word), word],
    );
    return rows.isEmpty ? null : rows.first['translation'] as String;
  }

  /// For each of [ids] (meanings of this language), the words of the other
  /// language linked to it, most common first — what the word page shows
  /// under each meaning.
  Future<Map<int, List<String>>> linkedWords(Iterable<int> ids) async {
    await init();
    if (ids.isEmpty) return {};
    final list = ids.toList();
    final (mine, other) = _isGreek ? ('el_id', 'en_id') : ('en_id', 'el_id');
    final rows = await _db!.rawQuery(
      'SELECT l.$mine AS id, o.word FROM links l '
      'JOIN main.entries o ON o.id = l.$other WHERE l.$mine IN '
      '(${List.filled(list.length, '?').join(',')}) ORDER BY o.sense, o.id',
      list,
    );
    final out = <int, List<String>>{};
    for (final r in rows) {
      final words = out.putIfAbsent(r['id'] as int, () => []);
      final w = r['word'] as String;
      if (!words.contains(w)) words.add(w);
    }
    return out;
  }

  /// [text]'s meanings in the other language, one per meaning of the word
  /// that is linked to the other language's words (most common meaning
  /// first); empty when the lexicon has no links for it.
  Future<List<WordTranslation>> translationsOf(String text) async {
    await init();
    final word = text.trim();
    if (word.isEmpty) return const [];
    final (mine, other) = _isGreek ? ('el_id', 'en_id') : ('en_id', 'el_id');
    final rows = await _db!.rawQuery(
      'SELECT e.id, e.pos, o.word FROM main.entries e '
      'JOIN links l ON l.$mine = e.id JOIN main.entries o ON o.id = l.$other '
      'WHERE e.lang = ? AND e.plain = ? '
      'ORDER BY (e.word = ?) DESC, CASE e.pos $_posRank ELSE 99 END, '
      'e.sense IS NULL, e.sense, e.id, o.sense, o.id',
      [language, _key(word), word],
    );
    final byMeaning = <int, (String, List<String>)>{};
    for (final r in rows) {
      final m = byMeaning.putIfAbsent(
        r['id'] as int,
        () => (r['pos'] as String, <String>[]),
      );
      final w = r['word'] as String;
      if (!m.$2.contains(w)) m.$2.add(w);
    }
    return [
      for (final (pos, words) in byMeaning.values.take(8))
        WordTranslation(pos, words),
    ];
  }

  /// Crossword answers with their clue (and its translation) as text.
  static const _puzzleSelect =
      'SELECT p.word, p.len, c.text AS clue, c.translation AS clue_tr, '
      'p.word_tr FROM puzzle_words p JOIN t.texts c ON c.id = p.clue_id ';

  static WordCandidate _candidate(Map<String, Object?> r) => WordCandidate(
    (r['word'] as String).replaceAll(' ', phraseGap),
    r['clue'] as String,
    r['clue_tr'] as String?,
    r['word_tr'] as String?,
  );

  /// How many single-word crossword answers there are (the rarest rank).
  Future<int> puzzlePoolSize() async {
    await init();
    final rows = await _db!.rawQuery(
      'SELECT max(rank) AS n FROM puzzle_words WHERE lang = ? AND phrase = 0',
      [language],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Random crossword answers (with clues) for the given difficulty window.
  Future<List<WordCandidate>> puzzleCandidates({
    required int minLen,
    required int maxLen,
    required int minRank,
    required int maxRank,
    bool phrases = false,
    int limit = 400,
    int phraseLimit = 30,
  }) async {
    await init();
    final rows = await _db!.rawQuery(
      '$_puzzleSelect WHERE p.lang = ? AND p.phrase = 0 '
      'AND p.len BETWEEN ? AND ? AND p.rank BETWEEN ? AND ? '
      'ORDER BY RANDOM() LIMIT ?',
      [language, minLen, maxLen, minRank, maxRank, limit],
    );
    // Phrases ("give up"): any that fit, up to the level's rarity. Their
    // spaces become phrase gaps, i.e. black squares in the grid.
    final phraseRows = !phrases
        ? const <Map<String, Object?>>[]
        : await _db!.rawQuery(
            '$_puzzleSelect WHERE p.lang = ? AND p.phrase = 1 '
            'AND p.len BETWEEN ? AND ? AND p.rank <= ? '
            'ORDER BY RANDOM() LIMIT ?',
            [language, minLen, maxLen, maxRank, phraseLimit],
          );
    return [
      for (final r in [...rows, ...phraseRows]) _candidate(r),
    ];
  }

  /// How many single-word answers a theme has (`puzzle_words.theme`).
  Future<int> themeSize(String theme) async {
    await init();
    final rows = await _db!.rawQuery(
      'SELECT count(*) AS n FROM puzzle_words '
      'WHERE lang = ? AND phrase = 0 AND theme = ?',
      [language, theme],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Random answers of one theme for a level: the theme's single-word
  /// answers, most common first, cut to the level's window (see
  /// themeWindow), then those of the right length.
  Future<List<WordCandidate>> themeCandidates({
    required String theme,
    required int level,
    required int minLen,
    required int maxLen,
    int limit = 400,
  }) async {
    await init();
    final rows = await _db!.rawQuery(
      '$_puzzleSelect WHERE p.lang = ? AND p.phrase = 0 AND p.theme = ? '
      'ORDER BY p.rank',
      [language, theme],
    );
    final (start, end) = themeWindow(level, rows.length);
    final picked = [
      for (final r in rows.sublist(start, end))
        if ((r['len'] as int) >= minLen && (r['len'] as int) <= maxLen) r,
    ]..shuffle();
    return [for (final r in picked.take(limit)) _candidate(r)];
  }
}
