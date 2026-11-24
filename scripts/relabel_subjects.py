#!/usr/bin/env python3
"""Give the English WordNet entries their subject (Law, Music, Botany...) from
WordNet itself, instead of the old labels, which were guessed by matching
words in the meaning ("court" in "courtship" made a dance Law).

    .models/venv/bin/python scripts/relabel_subjects.py [--write] [--report FILE]

Needs nltk with WordNet in .models/nltk_data:
    .models/venv/bin/pip install nltk
    .models/venv/bin/python -c "import nltk; nltk.download('wordnet', download_dir='.models/nltk_data')"

Each entry is matched to its WordNet meaning (same definition, part of
speech and word). Its subject is, in this order:
  1. the meaning's own topic tag in WordNet ("habeas corpus" -> law);
     a named place (a city, a country, a desert) is geography,
  2. for nouns, a topic tag inherited through "is a kind of" from a
     specific parent at most 4 steps up (every kind of court is law,
     because "court" is; but a tag on a broad idea like "substance" is not
     passed down),
  3. its broad WordNet group where that is safe: plants -> botany,
     animals -> zoology, body parts -> anatomy, foods -> culinary.
Otherwise it gets no subject: none is better than a wrong one. Entries that
don't come from WordNet (the medical ontologies, Lex Hopper's own) keep
theirs. Without --write it only prints what would change.
"""
import collections, csv, glob, re, sys
from pathlib import Path

import nltk

ROOT = Path(__file__).resolve().parents[1]
nltk.data.path.insert(0, str(ROOT / '.models/nltk_data'))
from nltk.corpus import wordnet as wn  # noqa: E402

# WordNet topic (or one of its broader topics) -> the app's subject id.
TOPICS = {
    'law.n.01': 'law', 'law.n.02': 'law', 'contract.n.01': 'law',
    'crime.n.01': 'police', 'police.n.01': 'police',
    'military.n.01': 'military', 'armed_forces.n.01': 'military',
    'terrorism.n.01': 'politics', 'politics.n.02': 'politics',
    'government.n.02': 'politics', 'election.n.01': 'politics',
    'diplomacy.n.01': 'diplomacy',
    'chemistry.n.01': 'chemistry', 'metallurgy.n.01': 'chemistry',
    'computer_science.n.01': 'computing', 'computer.n.01': 'computing',
    'mythology.n.01': 'mythology', 'folklore.n.01': 'mythology',
    'legend.n.01': 'mythology', 'arthurian_legend.n.01': 'mythology',
    'biology.n.01': 'biology', 'organism.n.01': 'biology',
    'microorganism.n.01': 'biology', 'bacteria.n.01': 'biology',
    'physiology.n.01': 'biology',
    'physics.n.01': 'physics',
    'music.n.01': 'music', 'music.n.03': 'music', 'music.n.04': 'music',
    'botany.n.02': 'botany', 'plant.n.02': 'botany',
    'mathematics.n.01': 'mathematics', 'statistics.n.01': 'statistics',
    'sport.n.01': 'sports', 'riding.n.01': 'sports', 'riding.n.02': 'sports',
    'card_game.n.01': 'games', 'chess.n.02': 'games',
    'bridge.n.05': 'games', 'board_game.n.01': 'games',
    'cooking.n.01': 'culinary',
    'medicine.n.01': 'medicine', 'medicine.n.03': 'medicine',
    'pathology.n.01': 'medicine', 'surgery.n.01': 'medicine',
    'psychiatry.n.01': 'medicine', 'obstetrics.n.01': 'medicine',
    'immunology.n.01': 'medicine',
    'anatomy.n.01': 'anatomy', 'dentistry.n.01': 'dentistry',
    'drug.n.01': 'pharmacology', 'pharmacology.n.01': 'pharmacology',
    'linguistics.n.01': 'linguistics', 'grammar.n.01': 'linguistics',
    'phonetics.n.01': 'linguistics', 'rhetoric.n.04': 'linguistics',
    'religion.n.01': 'religion', 'religion.n.02': 'religion',
    'theology.n.01': 'religion', 'church_service.n.01': 'religion',
    'roman_catholic.n.02': 'religion', 'old_testament.n.01': 'religion',
    'new_testament.n.01': 'religion', 'judaism.n.02': 'religion',
    'christianity.n.01': 'religion', 'hinduism.n.02': 'religion',
    'islam.n.02': 'religion', 'buddhism.n.02': 'religion',
    'geology.n.01': 'geology', 'mining.n.01': 'geology',
    'astronomy.n.01': 'astronomy', 'cosmology.n.02': 'astronomy',
    'psychology.n.01': 'psychology', 'psychoanalysis.n.01': 'psychology',
    'art.n.02': 'visual_arts', 'fine_arts.n.01': 'visual_arts',
    'architecture.n.02': 'architecture', 'architecture.n.03': 'architecture',
    'seafaring.n.01': 'maritime', 'navigation.n.01': 'maritime',
    'ship.n.01': 'maritime', 'boat.n.01': 'maritime',
    'philosophy.n.02': 'philosophy', 'logic.n.01': 'philosophy',
    'zoology.n.02': 'zoology', 'animal.n.01': 'zoology',
    'commerce.n.01': 'business', 'commercial_enterprise.n.02': 'business',
    'corporation.n.01': 'business', 'auction.n.02': 'business',
    'photography.n.01': 'photography',
    'antiquity.n.01': 'history', 'middle_ages.n.01': 'history',
    'archeology.n.01': 'history', 'heraldry.n.01': 'history',
    'history.n.01': 'history',
    'performing_arts.n.01': 'theatre_film', 'dramaturgy.n.01': 'theatre_film',
    'drama.n.03': 'theatre_film', 'theater.n.01': 'theatre_film',
    'ballet.n.01': 'theatre_film', 'dancing.n.01': 'theatre_film',
    'television.n.01': 'media', 'printing.n.03': 'media',
    'journalism.n.01': 'media',
    'air_travel.n.01': 'aviation', 'aircraft.n.01': 'aviation',
    'airplane.n.01': 'aviation', 'aeronautics.n.01': 'aviation',
    'electronics.n.01': 'electronics', 'electricity.n.01': 'physics',
    'optics.n.01': 'physics',
    'meteorology.n.02': 'meteorology',
    'driving.n.02': 'automotive', 'car.n.01': 'automotive',
    'economics.n.01': 'economics',
    'poetry.n.01': 'literature', 'literature.n.01': 'literature',
    'prosody.n.03': 'literature', 'writing.n.01': 'literature',
    'farming.n.01': 'agriculture', 'agriculture.n.02': 'agriculture',
    'animal_husbandry.n.01': 'animal_husbandry',
    'tax.n.01': 'finance', 'finance.n.02': 'finance',
    'finance.n.01': 'finance', 'banking.n.01': 'finance',
    'accounting.n.02': 'accounting', 'stock_exchange.n.01': 'stock_market',
    'telecommunication.n.01': 'telecommunications',
    'ecology.n.02': 'ecology',
    'masonry.n.03': 'construction', 'construction.n.01': 'construction',
    'anthropology.n.01': 'sociology', 'sociology.n.01': 'sociology',
    'river.n.01': 'geography', 'geography.n.01': 'geography',
    'veterinary_medicine.n.01': 'veterinary',
    'engineering.n.02': 'engineering',
    'education.n.01': 'education', 'education.n.02': 'education',
}

# Words whose WordNet tag fits one of their meanings but not the kinds
# under them ("record" is tagged photography, "section" music): their tag
# is not passed down.
NO_INHERIT = {'record.n.01', 'section.n.01', 'community.n.06'}

# Broad WordNet groups that are safe to turn into a subject.
GROUPS = {
    'noun.plant': 'botany', 'noun.animal': 'zoology',
    'noun.body': 'anatomy', 'noun.food': 'culinary',
}


def topic_subject(domain):
    """The app subject of a WordNet topic, or of one of its broader topics."""
    for s in [domain, *domain.closure(lambda x: x.hypernyms() +
                                      x.instance_hypernyms())]:
        if s.name() in TOPICS:
            return TOPICS[s.name()]
    return None


_cache = {}
MAX_STEPS = 4
MAX_KINDS = 300
_kinds_cache = {}


def _kinds(synset):
    """How many kinds of [synset] there are (all levels down)."""
    if synset not in _kinds_cache:
        _kinds_cache[synset] = sum(1 for _ in synset.closure(
            lambda x: x.hyponyms() + x.instance_hyponyms()))
    return _kinds_cache[synset]


def subject_of(synset):
    if synset in _cache:
        return _cache[synset]
    # 1. Its own topic tag; a named place is geography.
    found = next(filter(None, map(topic_subject, synset.topic_domains())),
                 None)
    if not found and synset.lexname() == 'noun.location' and \
            synset.instance_hypernyms():
        found = 'geography'  # a named place: a city, a country, a desert
    # 2. One inherited through "is a kind of", nearest first: nouns only,
    # at most MAX_STEPS up, and only from a specific parent (one with few
    # kinds under it): a tag on a broad idea like "substance" or
    # "institution" would spread to things outside its subject.
    if not found and synset.pos() == 'n':
        queue, seen = [synset], {synset}
        for _ in range(MAX_STEPS):
            nxt = []
            for s in queue:
                for h in s.hypernyms() + s.instance_hypernyms():
                    if h in seen:
                        continue
                    seen.add(h)
                    nxt.append(h)
                    if not found and _kinds(h) <= MAX_KINDS and \
                            h.name() not in NO_INHERIT:
                        found = next(filter(None, map(
                            topic_subject, h.topic_domains())), None)
            if found or not nxt:
                break
            queue = nxt
    # 3. Its broad group, where safe.
    if not found:
        found = GROUPS.get(synset.lexname())
    _cache[synset] = found
    return found


def norm(s):
    return re.sub(r'\W+', ' ', s.lower()).strip()


POS = {'noun': 'n', 'verb': 'v', 'adj': 'as', 'adv': 'r'}


def main():
    write = '--write' in sys.argv
    report = sys.argv[sys.argv.index('--report') + 1] \
        if '--report' in sys.argv else None
    meanings = {r['id']: r['text'] for r in csv.DictReader(
        open(ROOT / 'data/texts/en_meanings.csv', encoding='utf-8'))}
    by_definition = collections.defaultdict(list)
    for s in wn.all_synsets():
        by_definition[norm(s.definition())].append(s)

    stats = collections.Counter()
    changes = []
    for path in sorted(glob.glob(str(ROOT / 'data/lexicon/entries_en/*.csv'))):
        with open(path, encoding='utf-8', newline='') as f:
            reader = csv.DictReader(f)
            fields, rows = reader.fieldnames, list(reader)
        for r in rows:
            if r['source'] != 'WordNet':
                continue
            candidates = by_definition.get(
                norm(meanings.get(r['meaning_id'], '')), [])
            p = POS.get(r['pos'])
            if p:
                candidates = [s for s in candidates if s.pos() in p] \
                    or candidates
            if len(candidates) > 1:
                word = r['word'].replace(' ', '_')
                candidates = [s for s in candidates if any(
                    l.name().lower() == word for l in s.lemmas())] \
                    or candidates
            new = subject_of(candidates[0]) if len(candidates) == 1 else None
            stats['matched' if len(candidates) == 1 else 'unmatched'] += 1
            old = r['subject']
            stats['same' if old == (new or '') else
                  'added' if not old else
                  'removed' if not new else 'changed'] += 1
            if old != (new or ''):
                changes.append((r['word'], old, new or '',
                                meanings.get(r['meaning_id'], '')))
                r['subject'] = new or ''
        if write:
            with open(path, 'w', encoding='utf-8', newline='') as f:
                w = csv.DictWriter(f, fieldnames=fields)
                w.writeheader()
                w.writerows(rows)

    for k, v in sorted(stats.items()):
        print(f'{k:10} {v}')
    if report:
        with open(report, 'w', encoding='utf-8', newline='') as f:
            w = csv.writer(f)
            w.writerow(['word', 'old', 'new', 'meaning'])
            w.writerows(changes)
    print('written' if write else '(dry run: nothing written)')


if __name__ == '__main__':
    main()
