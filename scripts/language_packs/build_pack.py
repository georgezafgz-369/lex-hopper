#!/usr/bin/env python3
"""Build a downloadable language's dictionary (a "language pack"): one
SQLite file with the same tables as the built-in lexicon.db + texts.db, so
the app opens it the same way.

    .models/venv/bin/python scripts/language_packs/build_pack.py es

Words come from an open wordnet linked to Princeton WordNet:
  es  Multilingual Central Repository (via the Open Multilingual Wordnet),
      CC BY 3.0
  de  OdeNet, CC BY-SA 4.0 (.models/odenet/deWordNet.xml)
  it  MultiWordNet (via the Open Multilingual Wordnet), CC BY 3.0
  fr  WOLF (via the Open Multilingual Wordnet), CeCILL-C
  ru  Wiktionary via kaikki.org, CC BY-SA 4.0
      (.models/kaikki-ru/ru.jsonl.gz): each Russian meaning is matched to
      the WordNet meaning whose words best fit its English gloss
Their definitions and examples are English; translations made with the
pack's own OPUS-MT model are read from data/packs/<lang>/glosses.csv
(translate_glosses.py). OdeNet's own German definitions are used where it
has them. Subjects come from WordNet, as for English
(scripts/relabel_subjects.py).

Writes assets/packs/<lang>.db (not in git: it is uploaded, see
upload_language_pack.py) and prints its size.
"""
import collections, csv, re, sqlite3, sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
import relabel_subjects as R  # noqa: E402  (loads WordNet from .models)
from nltk.corpus import wordnet as wn  # noqa: E402

POS = {'n': 'noun', 'v': 'verb', 'a': 'adj', 's': 'adj', 'r': 'adv'}
SOURCES = {
    'es': 'Multilingual Central Repository (Open Multilingual Wordnet)',
    'de': 'OdeNet',
    'it': 'MultiWordNet (Open Multilingual Wordnet)',
    'fr': 'WOLF (Open Multilingual Wordnet)',
    'ru': 'Wiktionary (kaikki.org)',
}
OMW = {'es': 'spa', 'it': 'ita', 'fr': 'fra'}


_LATIN = str.maketrans('áàâäéèêëíìîïóòôöúùûüçё', 'aaaaeeeeiiiioooouuuucе')


def latin_plain(text):
    """Search key: lowercase, without accents (ñ and ß stay; Russian ё is
    е), as the app's latinPlain()."""
    return text.strip().lower().translate(_LATIN)


def words_omw(lang):
    """(synset, [words]) for every synset that has some in the Open
    Multilingual Wordnet (Spanish, Italian, French)."""
    for s in wn.all_synsets():
        words = [w.replace('_', ' ') for w in s.lemma_names(OMW[lang])]
        if words:
            yield s, words, None


_RU_POS = {'noun': 'n', 'verb': 'v', 'adj': 'a', 'adv': 'r'}
_PAREN = re.compile(r'\([^)]*\)')
# Senses left out: slang, jokes, rude or old words (абажур "head").
_RU_SKIP = {'slang', 'jocular', 'humorous', 'vulgar', 'derogatory',
            'offensive', 'obsolete', 'archaic', 'dated', 'nonstandard',
            'ironic', 'euphemistic'}
# (word, synset name) -> the meaning's place in the word's Wiktionary entry.
RU_ORDER = {}
_ru_count = collections.Counter()


def _ru_next(word):
    _ru_count[word] += 1
    return _ru_count[word]


def words_ru():
    """(synset, [Russian words]) from Wiktionary: each Russian meaning's
    English gloss ("house, building") picks the WordNet meaning of that
    part of speech whose words it names most (ties: the one WordNet lists
    first, the most common)."""
    import gzip, json
    by_synset = collections.defaultdict(list)
    with gzip.open(ROOT / '.models/kaikki-ru/ru.jsonl.gz', 'rt',
                   encoding='utf-8') as f:
        for line in f:
            e = json.loads(line)
            pos = _RU_POS.get(e.get('pos'))
            word = e.get('word', '')
            if not pos or not word or ' ' in word.strip() and len(
                    word.split()) > 3:
                continue
            for sense in e.get('senses', []):
                tags = set(sense.get('tags', []))
                if 'form-of' in tags or 'alt-of' in tags or \
                        sense.get('form_of') or sense.get('alt_of') or \
                        tags & _RU_SKIP:
                    continue
                glosses = sense.get('glosses') or []
                if not glosses:
                    continue
                gloss = _PAREN.sub('', glosses[-1]).strip().rstrip('.')
                terms = []
                for t in re.split(r'[,;]', gloss):
                    t = t.strip().lower()
                    t = re.sub(r'^(to|a|an|the) ', '', t)
                    if t and len(t.split()) <= 3:
                        terms.append(t.replace(' ', '_'))
                # "plot (in street addresses ...)": a narrow use of a single
                # English word, which WordNet's usual meaning would get wrong.
                if not terms or len(terms) == 1 and _PAREN.search(
                        glosses[-1]):
                    continue
                # Most words of the gloss first, then the meaning WordNet
                # lists first for them (the most common).
                best, score = None, (0, 0)
                for t in terms:
                    for rank, s in enumerate(wn.synsets(t, pos=pos)):
                        names = {n.lower() for n in s.lemma_names()}
                        hits = sum(x in names for x in terms)
                        sc = (hits, -rank)
                        if hits and (best is None or sc > score):
                            best, score = s, sc
                if best is not None:
                    by_synset[best].append(word)
                    # Wiktionary lists a word's meanings most usual first.
                    if (word, best.name()) not in RU_ORDER:
                        RU_ORDER[(word, best.name())] = _ru_next(word)
    for s, words in by_synset.items():
        yield s, list(dict.fromkeys(words)), None


def words_de(unlinked=False):
    """(synset, [German words], German definition or None) from OdeNet,
    matched to WordNet by its English definition. With [unlinked], also
    OdeNet's meanings without a WordNet match that have a German
    definition, as (None, words, definition, part of speech)."""
    by_def = collections.defaultdict(list)
    for s in wn.all_synsets():
        by_def[R.norm(s.definition())].append(s)
    # The Interlingual Index: OdeNet's ili="i107577" -> WordNet 3.0.
    ili = {}
    with open(ROOT / '.models/cili/ili-map-pwn30.tab', encoding='utf-8') as f:
        for line in f:
            i, offset = line.split()
            ili[i] = offset
    tree = ET.parse(ROOT / '.models/odenet/deWordNet.xml')
    lex = tree.getroot().find('Lexicon')
    members = collections.defaultdict(list)
    for e in lex.findall('LexicalEntry'):
        word = e.find('Lemma').get('writtenForm')
        for sense in e.findall('Sense'):
            members[sense.get('synset')].append(word)
    for syn in lex.findall('Synset'):
        english = syn.get('{https://globalwordnet.github.io/schemas/dc/}'
                          'description') or ''
        pos = syn.get('partOfSpeech')
        candidates = []
        if syn.get('ili') in ili:
            offset, p = ili[syn.get('ili')].split('-')
            try:
                candidates = [wn.synset_from_pos_and_offset(p, int(offset))]
            except Exception:  # noqa: BLE001  (an offset NLTK doesn't know)
                candidates = []
        if not candidates:
            candidates = [s for s in by_def.get(R.norm(english), [])
                          if s.pos() == pos or (pos == 'a' and s.pos() == 's')]
        words = members.get(syn.get('id'))
        if not words:
            continue
        d = syn.find('Definition')
        own = d.text.strip() if d is not None and d.text else None
        if len(candidates) == 1:
            # The WordNet definition (translated) always matches the link;
            # OdeNet's own is sometimes attached to the wrong meaning.
            yield candidates[0], words, None
        elif unlinked and own:
            yield None, words, own, pos


def build(lang):
    glosses = {}
    with open(ROOT / f'data/packs/{lang}/glosses.csv', encoding='utf-8',
              newline='') as f:
        for r in csv.DictReader(f):
            glosses[(r['synset'], r['kind'], int(r['order']))] = r['translation']

    entries, texts, examples, translations = [], [], [], {}
    text_id = entry_id = 0
    sense_of = collections.Counter()
    entry_synset = {}
    source = SOURCES[lang]
    rows = list(words_de(unlinked=True) if lang == 'de' else
                words_ru() if lang == 'ru' else words_omw(lang))
    # Most common meanings first, so each word's sense 1 is its usual one
    # (meanings without a WordNet match last).
    rows.sort(key=lambda r: -sum(l.count() for l in r[0].lemmas())
              if r[0] else 1)
    missing = 0
    for row in rows:
        synset, words, own_definition = row[:3]
        if synset is None:  # OdeNet only: German words and definition
            text_id += 1
            texts.append((text_id, lang, 'meaning', own_definition, None,
                          source))
            for word in dict.fromkeys(words):
                entry_id += 1
                plain = latin_plain(word)
                sense_of[plain] += 1
                synonyms = ','.join(w for w in dict.fromkeys(words)
                                    if w != word)
                if row[3] not in POS:
                    continue
                entries.append([
                    entry_id, lang, word, plain,
                    'phrase' if ' ' in word else 'word', POS[row[3]],
                    sense_of[plain], text_id, synonyms or None, None, None,
                    None, None, None, None, None, None, 'general', source])
            continue
        meaning = own_definition or glosses.get((synset.name(), 'meaning', 0))
        if not meaning:
            missing += 1
            continue
        text_id += 1
        meaning_id = text_id
        texts.append((meaning_id, lang, 'meaning', meaning,
                      synset.definition(), 'Open Multilingual Wordnet'))
        example_ids = []
        for i, english in enumerate(synset.examples()[:2]):
            tr = glosses.get((synset.name(), 'example', i))
            if tr:
                text_id += 1
                texts.append((text_id, lang, 'example', tr, english,
                               'Open Multilingual Wordnet'))
                example_ids.append(text_id)
        subject = R.subject_of(synset)
        english_word = synset.lemmas()[0].name().replace('_', ' ')
        for word in dict.fromkeys(words):
            entry_id += 1
            plain = latin_plain(word)
            sense_of[plain] += 1
            synonyms = ','.join(w for w in dict.fromkeys(words) if w != word)
            entries.append([
                entry_id, lang, word, plain,
                'phrase' if ' ' in word else 'word', POS[synset.pos()],
                sense_of[plain], meaning_id, synonyms or None, None, None,
                None, None, subject, None, None, None, 'general', source])
            entry_synset[entry_id] = synset.name()
            for order, t in enumerate(example_ids, 1):
                examples.append((entry_id, t, order))
            translations.setdefault(word, english_word)

    if lang == 'ru':
        # A word's meanings in its Wiktionary order, not WordNet's.
        by_word = collections.defaultdict(list)
        for e in entries:
            by_word[e[3]].append(e)
        for group in by_word.values():
            group.sort(key=lambda e: (
                RU_ORDER.get((e[2], entry_synset.get(e[0])), 99), e[6]))
            for n, e in enumerate(group, 1):
                e[6] = n

    out = ROOT / f'assets/packs/{lang}.db'
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    con = sqlite3.connect(out)
    # The same tables as the built-in databases (empty where the pack has
    # nothing, e.g. the English–Greek phrasebook and links).
    for db in ('lexicon', 'texts'):
        src = sqlite3.connect(ROOT / f'assets/{db}.db')
        for (sql,) in src.execute(
                "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL "
                "AND name NOT LIKE 'sqlite_%' ORDER BY type = 'view', "
                "type = 'index'"):
            con.execute(sql)
        src.close()

    labels = {}

    def label(t):
        return None if t is None else labels.setdefault(t, len(labels) + 1)

    con.executemany(
        f'INSERT INTO entry_rows VALUES ({",".join("?" * 19)})',
        [[r[0], r[1], r[2], r[3], label(r[4]), label(r[5]), r[6], r[7],
          r[8], r[9], r[10], r[11], label(r[12]), label(r[13]),
          label(r[14]), label(r[15]), r[16], label(r[17]), label(r[18])]
         for r in entries])
    con.executemany('INSERT INTO labels VALUES (?, ?)',
                    [(i, t) for t, i in labels.items()])
    con.executemany('INSERT INTO texts VALUES (?, ?, ?, ?, ?, ?)', texts)
    con.executemany('INSERT INTO entry_examples VALUES (?, ?, ?)', examples)
    con.executemany(
        'INSERT OR REPLACE INTO translations VALUES (?, ?, ?, ?, ?)',
        [(lang, w, latin_plain(w), en, source)
         for w, en in translations.items()])
    con.executemany(
        'INSERT OR IGNORE INTO phrase_words VALUES (?, ?, ?)',
        [(lang, w, r[0]) for r in entries if ' ' in r[3]
         for w in set(r[3].split(' ')) if w])
    con.commit()
    con.execute('VACUUM')
    con.close()
    words = len({r[3] for r in entries})
    print(f'{lang}: {len(entries):,} meanings of {words:,} words, '
          f'{len(examples):,} examples ({missing:,} meanings without a '
          f'definition left out) — {out.stat().st_size / 1e6:.1f} MB')


if __name__ == '__main__':
    build(sys.argv[1])
