// For tests that read the bundled databases with the sqlite3 command: runs
// [sql] on assets/lexicon.db (with assets/texts.db attached) where
// `puzzle_words` means the crossword words of [lang] ("en"/"el") with their
// clue (and its translation) as text, as the old dictionaries had it.

import 'dart:io';

String puzzleSql(String lang, String sql) {
  final out = Process.runSync('sqlite3', [
    '-separator',
    '\t',
    'assets/lexicon.db',
    "ATTACH 'assets/texts.db' AS t",
    'WITH pw AS (SELECT p.word, p.len, p.rank, c.text AS clue, '
        'c.translation AS clue_tr, p.phrase, p.word_tr, p.subject, p.theme '
        'FROM puzzle_words p JOIN t.texts c ON c.id = p.clue_id '
        "WHERE p.lang = '$lang') "
        '${sql.replaceAll('puzzle_words', 'pw')}',
  ]);
  if (out.exitCode != 0) throw StateError('sqlite3: ${out.stderr}');
  return (out.stdout as String).trim();
}
