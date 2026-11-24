#!/usr/bin/env python3
"""Build Lex Hopper's two databases from our own CSV files:

  assets/lexicon.db  words and short phrases (data/lexicon/)
  assets/texts.db    meanings, example sentences, crossword clues and long
                     phrases, each with its translation (data/texts/)

The CSV files are the source: edit them, then run this again.

    python3 scripts/build_databases.py

The Dictionary, the Translator and the games read both (the app opens
texts.db next to lexicon.db). See data/lexicon/README.md and
data/texts/README.md for the files and columns.

New rows: leave `id` empty and the build gives one. A new word in an
entries file may give its meaning as text in a `meaning` column instead of
a `meaning_id`; the build adds that text to the meanings.

Every row is checked: a missing word, an unknown type or part of speech,
an id used twice, or an id that points nowhere stops the build with the
file and line to fix (nothing is written then).
"""

from __future__ import annotations

import csv
import hashlib
import json
import sqlite3
import sys
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEX_SRC = ROOT / 'data' / 'lexicon'
TEXT_SRC = ROOT / 'data' / 'texts'
LEX_DB = ROOT / 'assets' / 'lexicon.db'
TEXT_DB = ROOT / 'assets' / 'texts.db'
VERSIONS = ROOT / 'assets' / 'databases.json'

TYPES = {'word', 'phrase', 'phrasal verb', 'idiom', 'proverb'}
POS = {'noun', 'verb', 'adj', 'adv', 'pron', 'prep', 'conj', 'interj',
       'det', 'art', 'part', 'num', 'phrase', 'abbr', 'prefix', 'suffix'}
# texts files: (file name, lang, kind)
TEXT_FILES = [
    ('en_meanings.csv', 'en', 'meaning'),
    ('en_meanings_medical.csv', 'en', 'meaning'),
    ('el_meanings.csv', 'el', 'meaning'),
    ('en_examples.csv', 'en', 'example'),
    ('el_examples.csv', 'el', 'example'),
    ('en_clues.csv', 'en', 'clue'),
    ('el_clues.csv', 'el', 'clue'),
]

errors: list[str] = []


def plain(word: str, lang: str) -> str:
    """Search key: lowercase; Greek also without accents (σπίτι -> σπιτι),
    as the app's greekPlain() does."""
    w = word.strip().lower()
    if lang != 'el':
        return w
    w = unicodedata.normalize('NFD', w)
    w = ''.join(c for c in w if unicodedata.category(c) != 'Mn')
    return unicodedata.normalize('NFC', w).replace('ς', 'σ')


_GREEK_MARKS = str.maketrans({
    'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω',
    'ϊ': 'ι', 'ϋ': 'υ', 'ΐ': 'ι', 'ΰ': 'υ', 'ς': 'σ'})


def phrase_key(text: str) -> str:
    """Phrasebook search key: lowercase, Greek without accents, words only
    ("Καλημέρα, τι κάνεις;" -> "καλημερα τι κανεισ"). The same as the
    app's phraseKey(); "(formal)"-style notes don't count."""
    t = re.sub(r'\([^)]*\)', ' ', text).lower().translate(_GREEK_MARKS)
    return ' '.join(re.sub(r'[\W_]+', ' ', t).split())


def strip_note(text: str) -> str:
    """The phrase without its "(formal)"-style note, as shown in the app."""
    return ' '.join(re.sub(r'\([^)]*\)', ' ', text).split())


def read(path: Path):
    with open(path, newline='', encoding='utf-8') as f:
        for i, row in enumerate(csv.DictReader(f), start=2):
            yield i, {k: (v if v not in ('', None) else None)
                      for k, v in row.items()}


class Ids:
    """Hands out ids: the ones given in the files (each only once), then
    new ones above them for rows without an id."""

    def __init__(self) -> None:
        self.used: set[int] = set()
        self.pending: list[list] = []

    def take(self, value: str | None, where: str, row: list) -> None:
        if value is None:
            self.pending.append(row)
            return
        i = int(value)
        if i in self.used:
            errors.append(f'{where}: id {i} is used twice')
        self.used.add(i)
        row[0] = i

    def finish(self) -> None:
        nxt = max(self.used, default=0) + 1
        for row in self.pending:
            row[0] = nxt
            self.used.add(nxt)
            nxt += 1


class Labels:
    """Short texts that repeat a lot (types, parts of speech, sources):
    stored once each."""

    def __init__(self) -> None:
        self.ids: dict[str, int] = {}

    def __call__(self, t: str | None) -> int | None:
        if t is None:
            return None
        return self.ids.setdefault(t, len(self.ids) + 1)


def build() -> None:
    for db in (LEX_DB, TEXT_DB):
        if db.exists():
            db.unlink()

    # ── Texts ──────────────────────────────────────────────────────────────
    text_ids = Ids()
    texts: list[list] = []   # id, lang, kind, text, translation, source
    kind_of: dict[int, tuple[str, str]] = {}
    for name, lang, kind in TEXT_FILES:
        for line, r in read(TEXT_SRC / name):
            if not r['text']:
                errors.append(f'texts/{name}:{line}: the text is empty')
                continue
            row = [None, lang, kind, r['text'], r['translation'],
                   r['source'] if r['translation'] else None]
            text_ids.take(r['id'], f'texts/{name}:{line}', row)
            texts.append(row)

    # ── Phrasebook: everyday sentences, English and Greek ──────────────────
    phrasebook: list[tuple] = []  # en, el, en_key, el_key, topic
    for line, r in read(TEXT_SRC / 'phrasebook.csv'):
        if not r['en'] or not r['el']:
            errors.append(f'texts/phrasebook.csv:{line}: en and el are both '
                          'needed')
            continue
        en, el = strip_note(r['en']), strip_note(r['el'])
        phrasebook.append((en, el, phrase_key(r['en']), phrase_key(r['el']),
                           r['topic']))

    # ── Entries (lexicon) and long phrases (texts) ─────────────────────────
    entry_ids = Ids()
    entries: list[list] = []
    new_meanings: list[tuple[list, str, str]] = []  # (row, lang, text)
    lang_of: dict[int, str] = {}

    def entry_files():
        for p in sorted((LEX_SRC / 'entries_en').glob('*.csv')):
            yield 'en', p
        for p in sorted((LEX_SRC / 'entries_en_medical').glob('*.csv')):
            yield 'en', p
        yield 'el', LEX_SRC / 'entries_el.csv'

    def check_entry(r: dict, where: str, word_col: str) -> str | None:
        word = r[word_col]
        if not word or not r['pos']:
            errors.append(f'{where}: {word_col} and pos are needed')
            return None
        t = r['type'] or ('phrase' if ' ' in word.strip() else 'word')
        if t not in TYPES:
            errors.append(f'{where}: unknown type "{t}" '
                          f'(one of: {", ".join(sorted(TYPES))})')
        if r['pos'] not in POS:
            errors.append(f'{where}: unknown pos "{r["pos"]}"')
        if not r.get('meaning_id') and not r.get('meaning'):
            errors.append(f'{where}: needs a meaning_id or a meaning')
        return t

    for lang, path in entry_files():
        name = path.relative_to(ROOT / 'data')
        for line, r in read(path):
            where = f'{name}:{line}'
            t = check_entry(r, where, 'word')
            if t is None:
                continue
            row = [None, lang, r['word'].strip(), plain(r['word'], lang), t,
                   r['pos'], r['sense'],
                   int(r['meaning_id']) if r['meaning_id'] else None,
                   r['synonyms'], r['antonyms'], r['related'], r['origin'],
                   r['category'], r['subject'], r['usage'], r['structure'],
                   r['code'], r['domain'] or 'general',
                   r['source'] or 'Lex Hopper']
            entry_ids.take(r['id'], where, row)
            entries.append(row)
            if row[7] is None and r.get('meaning'):
                new_meanings.append((row, lang, r['meaning']))

    phrases: list[list] = []
    for lang in ('en', 'el'):
        name = f'{lang}_phrases.csv'
        for line, r in read(TEXT_SRC / name):
            where = f'texts/{name}:{line}'
            t = check_entry(r, where, 'phrase')
            if t is None:
                continue
            row = [None, lang, r['phrase'].strip(), plain(r['phrase'], lang),
                   t, r['pos'], r['sense'],
                   int(r['meaning_id']) if r['meaning_id'] else None,
                   r['synonyms'], r['antonyms'], r['related'], r['origin'],
                   r['category'], r['subject'], r['usage'], r['structure'],
                   r['code'], r['domain'] or 'general',
                   r['source'] or 'Lex Hopper', None]
            entry_ids.take(r['id'], where, row)
            phrases.append(row)
            if row[7] is None and r.get('meaning'):
                new_meanings.append((row, lang, r['meaning']))

    # New meanings typed as text: add them to the texts.
    for row, lang, text in new_meanings:
        t = [None, lang, 'meaning', text, None, None]
        text_ids.pending.append(t)
        texts.append(t)
    text_ids.finish()
    for (row, _, _), t in zip(new_meanings, texts[-len(new_meanings):]
                              if new_meanings else []):
        row[7] = t[0]
    entry_ids.finish()
    for t in texts:
        kind_of[t[0]] = (t[1], t[2])
    for row in entries + phrases:
        lang_of[row[0]] = row[1]
        k = kind_of.get(row[7])
        if row[7] is not None and (k is None or k[1] != 'meaning'):
            errors.append(f'{row[1]} "{row[2]}": meaning_id {row[7]} is '
                          f'not a meaning in data/texts')

    # ── Main translations (for words and phrases alike) ────────────────────
    translations: list[tuple] = []
    main: dict[tuple[str, str], str] = {}
    for lang in ('en', 'el'):
        path = LEX_SRC / f'translations_{lang}.csv'
        if path.exists():
            for _, r in read(path):
                if r['word'] and r['translation']:
                    translations.append((lang, r['word'],
                                         plain(r['word'], lang),
                                         r['translation'],
                                         r['source'] or 'Lex Hopper'))
                    main[(lang, r['word'])] = r['translation']
    for row in phrases:
        row[19] = main.get((row[1], row[2]))

    # ── Links and the rest ─────────────────────────────────────────────────
    links = []
    for line, r in read(LEX_SRC / 'links.csv'):
        a, b = int(r['en_id']), int(r['el_id'])
        if lang_of.get(a) != 'en' or lang_of.get(b) != 'el':
            errors.append(f'lexicon/links.csv:{line}: {a} must be an '
                          f'English and {b} a Greek entry id')
            continue
        links.append((a, b, r['source'] or 'Lex Hopper'))

    examples = []
    for line, r in read(LEX_SRC / 'entry_examples.csv'):
        e, t = int(r['entry_id']), int(r['text_id'])
        if e not in lang_of:
            errors.append(f'lexicon/entry_examples.csv:{line}: no entry {e}')
        elif kind_of.get(t) != (lang_of[e], 'example'):
            errors.append(f'lexicon/entry_examples.csv:{line}: text {t} '
                          f'is not a {lang_of[e]} example')
        else:
            examples.append((e, t, int(r['order'] or 1)))

    puzzle = []
    for lang in ('en', 'el'):
        for line, r in read(LEX_SRC / f'puzzle_words_{lang}.csv'):
            c = int(r['clue_id'])
            if kind_of.get(c) != (lang, 'clue'):
                errors.append(f'lexicon/puzzle_words_{lang}.csv:{line}: '
                              f'clue_id {c} is not a {lang} clue')
            puzzle.append((lang, r['word'], int(r['len']), int(r['rank']), c,
                           int(r['phrase'] or 0), r['word_tr'], r['subject'],
                           r['theme']))

    if errors:
        print(f'{len(errors)} problem(s) to fix (nothing was written):',
              file=sys.stderr)
        for e in errors[:50]:
            print('  ' + e, file=sys.stderr)
        sys.exit(1)

    # ── Write texts.db ─────────────────────────────────────────────────────
    con = sqlite3.connect(TEXT_DB)
    con.executescript('''
      CREATE TABLE texts (id INTEGER PRIMARY KEY, lang TEXT NOT NULL,
        kind TEXT NOT NULL, text TEXT NOT NULL, translation TEXT,
        source TEXT);
      CREATE TABLE phrases (id INTEGER PRIMARY KEY, lang TEXT NOT NULL,
        phrase TEXT NOT NULL, plain TEXT NOT NULL, type TEXT NOT NULL,
        pos TEXT NOT NULL, sense INTEGER, meaning_id INTEGER, synonyms TEXT,
        antonyms TEXT, related TEXT, origin TEXT, category TEXT,
        subject TEXT, usage TEXT, structure TEXT, code TEXT,
        domain TEXT NOT NULL, source TEXT NOT NULL, translation TEXT);
    ''')
    con.executemany('INSERT INTO texts VALUES (?, ?, ?, ?, ?, ?)', texts)
    con.executemany(f'INSERT INTO phrases VALUES ({",".join("?" * 20)})',
                    phrases)
    con.execute('CREATE INDEX idx_phrases_plain ON phrases(lang, plain, phrase)')
    con.execute('CREATE TABLE phrasebook (id INTEGER PRIMARY KEY, '
                'en TEXT NOT NULL, el TEXT NOT NULL, en_key TEXT NOT NULL, '
                'el_key TEXT NOT NULL, topic TEXT)')
    con.executemany('INSERT INTO phrasebook (en, el, en_key, el_key, topic) '
                    'VALUES (?, ?, ?, ?, ?)', phrasebook)
    con.execute('CREATE INDEX idx_phrasebook_en ON phrasebook(en_key)')
    con.execute('CREATE INDEX idx_phrasebook_el ON phrasebook(el_key)')
    con.commit()
    con.execute('VACUUM')
    con.close()

    # ── Write lexicon.db ───────────────────────────────────────────────────
    con = sqlite3.connect(LEX_DB)
    con.executescript('''
      CREATE TABLE labels (id INTEGER PRIMARY KEY, text TEXT NOT NULL);
      CREATE TABLE entry_rows (
        id INTEGER PRIMARY KEY, lang TEXT NOT NULL, word TEXT NOT NULL,
        plain TEXT NOT NULL, type_id INTEGER, pos_id INTEGER, sense INTEGER,
        meaning_id INTEGER NOT NULL, synonyms TEXT, antonyms TEXT,
        related TEXT, origin TEXT, category_id INTEGER, subject_id INTEGER,
        usage_id INTEGER, structure_id INTEGER, code TEXT,
        domain_id INTEGER, source_id INTEGER);
      CREATE VIEW entries AS SELECT e.id, e.lang, e.word, e.plain,
        l1.text AS type, l2.text AS pos, e.sense, e.meaning_id, e.synonyms,
        e.antonyms, e.related, e.origin, l3.text AS category,
        l4.text AS subject, l5.text AS usage, l6.text AS structure, e.code,
        l7.text AS domain, l8.text AS source
        FROM entry_rows e
        LEFT JOIN labels l1 ON l1.id = e.type_id
        LEFT JOIN labels l2 ON l2.id = e.pos_id
        LEFT JOIN labels l3 ON l3.id = e.category_id
        LEFT JOIN labels l4 ON l4.id = e.subject_id
        LEFT JOIN labels l5 ON l5.id = e.usage_id
        LEFT JOIN labels l6 ON l6.id = e.structure_id
        LEFT JOIN labels l7 ON l7.id = e.domain_id
        LEFT JOIN labels l8 ON l8.id = e.source_id;
      CREATE TABLE entry_examples (entry_id INTEGER NOT NULL,
        text_id INTEGER NOT NULL, ord INTEGER NOT NULL);
      CREATE TABLE links (en_id INTEGER NOT NULL, el_id INTEGER NOT NULL,
        source TEXT NOT NULL, PRIMARY KEY (en_id, el_id)) WITHOUT ROWID;
      CREATE TABLE translations (lang TEXT NOT NULL, word TEXT NOT NULL,
        plain TEXT NOT NULL, translation TEXT NOT NULL, source TEXT NOT NULL,
        PRIMARY KEY (lang, word)) WITHOUT ROWID;
      CREATE TABLE aliases (lang TEXT NOT NULL, alias TEXT NOT NULL,
        plain TEXT NOT NULL, entry_id INTEGER NOT NULL);
      CREATE TABLE word_info (lang TEXT NOT NULL, word TEXT NOT NULL,
        ipa TEXT, syllables INTEGER, adjectives TEXT,
        PRIMARY KEY (lang, word)) WITHOUT ROWID;
      CREATE TABLE word_forms (lang TEXT NOT NULL, word TEXT NOT NULL,
        pos TEXT NOT NULL, forms TEXT NOT NULL,
        PRIMARY KEY (lang, word, pos)) WITHOUT ROWID;
      CREATE TABLE word_examples (lang TEXT NOT NULL, word TEXT NOT NULL,
        text_id INTEGER NOT NULL);
      CREATE TABLE puzzle_words (lang TEXT NOT NULL, word TEXT NOT NULL,
        len INTEGER NOT NULL, rank INTEGER NOT NULL,
        clue_id INTEGER NOT NULL, phrase INTEGER NOT NULL DEFAULT 0,
        word_tr TEXT, subject TEXT, theme TEXT,
        PRIMARY KEY (lang, word)) WITHOUT ROWID;
    ''')
    label = Labels()
    con.executemany(
        f'INSERT INTO entry_rows VALUES ({",".join("?" * 19)})',
        [[r[0], r[1], r[2], r[3], label(r[4]), label(r[5]), r[6], r[7],
          r[8], r[9], r[10], r[11], label(r[12]), label(r[13]),
          label(r[14]), label(r[15]), r[16], label(r[17]), label(r[18])]
         for r in entries])
    con.executemany('INSERT INTO labels VALUES (?, ?)',
                    [(i, t) for t, i in label.ids.items()])
    con.executemany('INSERT INTO entry_examples VALUES (?, ?, ?)', examples)
    con.executemany('INSERT OR IGNORE INTO links VALUES (?, ?, ?)', links)
    con.executemany('INSERT OR REPLACE INTO translations VALUES '
                    '(?, ?, ?, ?, ?)', translations)
    for lang in ('en', 'el'):
        con.executemany(
            'INSERT INTO aliases VALUES (?, ?, ?, ?)',
            [(lang, r['alias'], plain(r['alias'], lang), int(r['entry_id']))
             for _, r in read(LEX_SRC / f'aliases_{lang}.csv')])
        con.executemany(
            'INSERT OR REPLACE INTO word_forms VALUES (?, ?, ?, ?)',
            [(lang, r['word'], r['pos'], r['forms'])
             for _, r in read(LEX_SRC / f'word_forms_{lang}.csv')])
    con.executemany(
        'INSERT OR REPLACE INTO word_info VALUES (?, ?, ?, ?, ?)',
        [('en', r['word'], r['ipa'], r['syllables'], r['adjectives'])
         for _, r in read(LEX_SRC / 'word_info_en.csv')])
    con.executemany(
        'INSERT INTO word_examples VALUES (?, ?, ?)',
        [('en', r['word'], int(r['text_id']))
         for _, r in read(LEX_SRC / 'word_examples_en.csv')])
    con.executemany('INSERT OR REPLACE INTO puzzle_words VALUES '
                    '(?, ?, ?, ?, ?, ?, ?, ?, ?)', puzzle)
    # Each word of an everyday multi-word entry -> that entry, so the word
    # page finds "phrases with this word" directly instead of reading every
    # entry. (Medical names are left out: they'd triple the table.)
    con.execute('CREATE TABLE phrase_words (lang TEXT NOT NULL, '
                'word TEXT NOT NULL, entry_id INTEGER NOT NULL, '
                'PRIMARY KEY (lang, word, entry_id)) WITHOUT ROWID')
    con.executemany(
        'INSERT OR IGNORE INTO phrase_words VALUES (?, ?, ?)',
        [(r[1], w, r[0]) for r in entries + phrases
         if ' ' in r[3] and r[17] != 'medical'
         for w in set(r[3].split(' ')) if w])
    con.executescript('''
      -- (lang, plain, word): lookups by search key, and the A–Z list in
      -- order without sorting.
      CREATE INDEX idx_entries_plain ON entry_rows(lang, plain, word);
      CREATE INDEX idx_entry_examples ON entry_examples(entry_id);
      CREATE INDEX idx_links_el ON links(el_id);
      CREATE INDEX idx_translations_plain ON translations(lang, plain);
      CREATE INDEX idx_aliases_plain ON aliases(lang, plain);
      CREATE INDEX idx_aliases_entry ON aliases(entry_id);
      CREATE INDEX idx_puzzle_rank ON puzzle_words(lang, len, rank);
    ''')
    con.commit()
    con.execute('VACUUM')
    con.close()

    # A fingerprint of each database, for the app: it names its copy on the
    # phone after it, so a changed database is copied again by itself.
    def fingerprint(path: Path) -> str:
        h = hashlib.sha1()
        with open(path, 'rb') as f:
            for chunk in iter(lambda: f.read(1 << 20), b''):
                h.update(chunk)
        return h.hexdigest()[:12]
    # The app downloads the databases from Hugging Face; the upload writes
    # where from (scripts/upload_databases.py). A rebuild that changes them
    # leaves the app without that until the upload runs.
    versions = {'lexicon': fingerprint(LEX_DB), 'texts': fingerprint(TEXT_DB)}
    old = json.loads(VERSIONS.read_text()) if VERSIONS.exists() else {}
    if all(old.get(k) == v for k, v in versions.items()):
        versions = old
    else:
        print('The databases changed: upload them with '
              '.models/venv/bin/python scripts/upload_databases.py')
    VERSIONS.write_text(json.dumps(versions, indent=2) + '\n',
                        encoding='utf-8')

    translated = sum(1 for t in texts if t[4])
    print(f'lexicon.db: {len(entries):,} meanings of words and short '
          f'phrases, {len(links):,} links, {len(translations):,} main '
          f'translations — {LEX_DB.stat().st_size / 1e6:.1f} MB')
    print(f'texts.db: {len(texts):,} texts ({translated:,} translated), '
          f'{len(phrases):,} long phrases — '
          f'{TEXT_DB.stat().st_size / 1e6:.1f} MB')


if __name__ == '__main__':
    build()
