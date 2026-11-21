#!/usr/bin/env python3
"""Turn "word<TAB>translation" files (e.g. made by tool/translate_list.dart
from a list of words) into the lexicon's main
translations: data/lexicon/translations_en.csv (English word -> Greek) and
translations_el.csv (Greek word -> English), source "machine".

Rows already in those CSV files win: an edited translation (or any row not
marked "machine") is never overwritten.

The machine is good with plain single words (hand -> χέρι) but weak with
phrases and odd word forms, so the lexicon's own links (from the seed)
win there:
  * phrasal verbs, idioms, proverbs and other phrases: the linked word
    most of their meanings lead to (give up -> εγκαταλείπω, not "παραιτώ");
  * a verb in another form than the dictionary one ("feel" ->
    αισθάνονται "they feel"): the linked word that starts the same way
    (αισθάνομαι);
  * a machine answer that isn't a word the lexicon knows, starts with
    "να", or is just the word itself untranslated (win -> Κερδίστε "win!",
    δειλιάζω -> "doggle"): the linked word of the most common meaning.
Such rows are marked source "link"; the machine's are "machine". Both are
replaced by a new import; any other source (a hand-checked row) is kept.
Needs assets/lexicon.db (scripts/build_lexicon.py) for the links.

    python3 scripts/import_word_translations.py words_to_el.tsv words_to_en.tsv
"""

from __future__ import annotations

import csv
import sqlite3
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEXICON = ROOT / 'data' / 'lexicon'
LEXICON_DB = ROOT / 'assets' / 'lexicon.db'
STEM = 5  # letters that must match to count as the same word


def plain(w: str) -> str:
    w = unicodedata.normalize('NFD', w.strip().lower())
    w = ''.join(c for c in w if unicodedata.category(c) != 'Mn')
    return unicodedata.normalize('NFC', w).replace('ς', 'σ')


def linked_words(lang: str) -> dict[str, list[str]]:
    """word (in [lang]) -> its linked words in the other language, the one
    most of its meanings lead to first."""
    if not LEXICON_DB.exists():
        return {}
    mine, other = ('en_id', 'el_id') if lang == 'en' else ('el_id', 'en_id')
    con = sqlite3.connect(LEXICON_DB)
    out: dict[str, list[str]] = {}
    votes: dict[str, dict[str, int]] = {}
    for word, linked in con.execute(
            f'SELECT e.word, o.word FROM entries e '
            f'JOIN links l ON l.{mine} = e.id '
            f'JOIN entries o ON o.id = l.{other} WHERE e.lang = ? '
            f'ORDER BY e.word, e.sense, o.sense, o.id', (lang,)):
        words = out.setdefault(word, [])
        if linked not in words:
            words.append(linked)
        v = votes.setdefault(word, {})
        v[linked] = v.get(linked, 0) + 1
    con.close()
    # The word most of its meanings lead to first (give up: εγκαταλείπω,
    # 3 meanings, before εκπίπτω, 1); ties keep the most common meaning's.
    for word, words in out.items():
        v = votes[word]
        words.sort(key=lambda w: -v[w])
    return out


def phrase_words(lang: str) -> set[str]:
    """Words of [lang] that are phrasal verbs, idioms, proverbs or phrases."""
    con = sqlite3.connect(LEXICON_DB)
    out = {w for (w,) in con.execute(
        "SELECT DISTINCT word FROM entries WHERE lang = ? AND type IN "
        "('phrasal verb', 'idiom', 'proverb', 'phrase')", (lang,))}
    con.close()
    return out


def known_words(lang: str) -> set[str]:
    """Every word and phrase of [lang] in the lexicon, as plain text."""
    con = sqlite3.connect(LEXICON_DB)
    out = {p for (p,) in con.execute(
        'SELECT DISTINCT plain FROM entry_rows WHERE lang = ?', (lang,))}
    out |= {plain(a) for (a,) in con.execute(
        'SELECT alias FROM aliases WHERE lang = ?', (lang,))}
    con.close()
    return out


def choose(word: str, machine: str, linked: list[str], is_phrase: bool,
           known: set[str]) -> tuple[str, str]:
    """(main translation, source "machine" or "link") — see the top of
    this file."""
    if not linked:
        return machine, 'machine'
    m = plain(machine)
    if any(plain(w) == m for w in linked):
        return machine, 'machine'  # the machine and the links agree
    if is_phrase:
        return linked[0], 'link'
    form = dictionary_form(machine, linked)
    if form != machine:
        return form, 'link'
    odd = (m == plain(word) or m.startswith('να ')
           or (' ' not in m and m not in known))
    return (linked[0], 'link') if odd else (machine, 'machine')


# Greek verb endings: a conjugated form (αισθάνονται "they feel") and the
# dictionary form (αισθάνομαι "I feel"), all without accents.
CONJUGATED = ('ονται', 'ουνται', 'ιουνται', 'εται', 'ειται', 'αται', 'ουν',
              'ουμε', 'ετε', 'εις', 'ει', 'ηκε', 'ηκαν', 'θηκε', 'θηκαν',
              'ουσε', 'ουσαν', 'αμε', 'ατε', 'αν')
DICTIONARY_FORM = ('ω', 'ομαι', 'ουμαι', 'αμαι', 'ιεμαι')


def dictionary_form(machine: str, linked: list[str]) -> str:
    """When [machine] is a Greek verb in a conjugated form and a linked word
    is the same verb in its dictionary form (same first letters), that
    linked word; otherwise [machine] itself. Nouns and other words are
    left alone (επιστροφή is not επιστρέφω)."""
    m = plain(machine)
    if ' ' in m or len(m) < STEM or not m.endswith(CONJUGATED):
        return machine
    for w in linked:
        p = plain(w)
        if (' ' not in p and p != m and p.endswith(DICTIONARY_FORM)
                and p[:STEM] == m[:STEM]):
            return w
    return machine


def read_tsv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        word, tab, tr = line.partition('\t')
        if tab and word.strip() and tr.strip():
            out[word.strip()] = tr.strip()
    return out


def merge(tsv: Path, csv_path: Path, lang: str) -> None:
    rows: dict[str, tuple[str, str]] = {}
    if csv_path.exists():
        with open(csv_path, newline='', encoding='utf-8') as f:
            for r in csv.DictReader(f):
                rows[r['word']] = (r['translation'], r['source'])
    added = fixed = 0
    links = linked_words(lang)
    phrases = phrase_words(lang)
    known = known_words('el' if lang == 'en' else 'en')
    for word, machine in read_tsv(tsv).items():
        tr, source = choose(word, machine, links.get(word, []),
                            word in phrases or ' ' in word, known)
        if source == 'link':
            fixed += 1
        kept = rows.get(word)
        if kept and kept[1] not in ('machine', 'link'):
            continue  # checked by hand: keep it
        if kept != (tr, source):
            added += 1
        rows[word] = (tr, source)
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['word', 'translation', 'source'])
        for word in sorted(rows, key=str.lower):
            w.writerow([word, *rows[word]])
    print(f'{csv_path.name}: {len(rows):,} words ({added:,} new or updated, '
          f'{fixed:,} from the dictionary links)')


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    merge(Path(sys.argv[1]), LEXICON / 'translations_en.csv', 'en')
    merge(Path(sys.argv[2]), LEXICON / 'translations_el.csv', 'el')


if __name__ == '__main__':
    main()
