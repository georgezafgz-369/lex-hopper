#!/usr/bin/env python3
"""Translate WordNet's English definitions and examples for a language
pack (the open wordnets give the words, not the definitions), with the
pack's own English → <lang> OPUS-MT model, in parallel and resumable.

    .models/venv/bin/python scripts/language_packs/translate_glosses.py es \\
        .models/pruned-big-en-es-int8 [--workers 6] [--limit N]

Writes data/packs/<lang>/glosses.csv: synset, kind (meaning/example),
order, English, translation. Lines already there are kept (run it again to
carry on).
"""
import csv, json, multiprocessing as mp, sys, time
from pathlib import Path

import nltk

ROOT = Path(__file__).resolve().parents[2]
nltk.data.path.insert(0, str(ROOT / '.models/nltk_data'))
OMW = {'es': 'spa', 'it': 'ita', 'fr': 'fra'}

_opus = None


ISO3 = {'es': 'spa', 'de': 'deu', 'it': 'ita', 'fr': 'fra', 'ru': 'rus'}


def _load(model_dir, lang):
    global _opus
    import numpy as np, onnxruntime as ort, sentencepiece as spm  # noqa
    src = open(ROOT / 'scripts/opus_mt/greedy_pruned.py').read()
    head, cls = src[:src.index('class Opus')], src[src.index('class Opus'):]
    lines = cls.split('\n')
    body = [lines[0]]
    for line in lines[1:]:
        if line and not line.startswith((' ', '\t')):
            break
        body.append(line)
    ns = {}
    exec(head + '\n'.join(body), ns)
    _opus = ns['Opus'](model_dir)
    # A multilingual model (German) writes the language of its tag.
    tag = f'>>{ISO3[lang]}<<'
    if tag in _opus.src:
        encode = _opus.spm.encode
        _opus.spm.encode = lambda text, out_type=str: [tag] + encode(
            text, out_type=out_type)


def _translate(item):
    key, text = item
    return key, _opus(text)


def jobs(lang, wn):
    """(synset, kind, order) -> English, for every synset with words in
    [lang]: its definition (unless the wordnet has its own), and its first
    two examples."""
    out = {}
    if lang == 'de':
        sys.path.insert(0, str(ROOT / 'scripts/language_packs'))
        from build_pack import words_de
        synsets = [(s, own) for s, _, own in words_de()]
    elif lang == 'ru':
        sys.path.insert(0, str(ROOT / 'scripts/language_packs'))
        from build_pack import words_ru
        synsets = [(s, None) for s, _, _ in words_ru()]
    else:
        synsets = [(s, None) for s in wn.all_synsets()
                   if s.lemma_names(OMW.get(lang, lang))]
    for s, own in synsets:
        if not own:
            out[(s.name(), 'meaning', 0)] = s.definition()
        for i, e in enumerate(s.examples()[:2]):
            out[(s.name(), 'example', i)] = e
    return out


def main():
    lang, model = sys.argv[1], sys.argv[2]
    workers = int(sys.argv[sys.argv.index('--workers') + 1]) \
        if '--workers' in sys.argv else 6
    limit = int(sys.argv[sys.argv.index('--limit') + 1]) \
        if '--limit' in sys.argv else None
    from nltk.corpus import wordnet as wn
    todo = jobs(lang, wn)
    path = ROOT / f'data/packs/{lang}/glosses.csv'
    path.parent.mkdir(parents=True, exist_ok=True)
    done = set()
    if path.exists():
        with open(path, encoding='utf-8', newline='') as f:
            for r in csv.DictReader(f):
                done.add((r['synset'], r['kind'], int(r['order'])))
    items = [(k, v) for k, v in todo.items() if k not in done]
    if limit:
        items = items[:limit]
    print(f'{len(todo):,} to translate, {len(done):,} done, '
          f'{len(items):,} now', flush=True)
    new = not path.exists()
    with open(path, 'a', encoding='utf-8', newline='') as f:
        w = csv.writer(f)
        if new:
            w.writerow(['synset', 'kind', 'order', 'english', 'translation'])
        start = time.time()
        with mp.Pool(workers, initializer=_load,
                     initargs=(model, lang)) as pool:
            for n, (key, tr) in enumerate(
                    pool.imap_unordered(_translate, items, chunksize=16), 1):
                w.writerow([key[0], key[1], key[2], todo[key], tr])
                if n % 500 == 0:
                    f.flush()
                    rate = n / (time.time() - start)
                    print(f'{n:,}/{len(items):,} — {rate:.1f}/s, '
                          f'{(len(items) - n) / rate / 60:.0f} min left',
                          flush=True)
    print('done', flush=True)


if __name__ == '__main__':
    main()
