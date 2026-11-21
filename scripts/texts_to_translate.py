#!/usr/bin/env python3
"""List the texts in data/texts/ that have no translation yet, for
tool/translate_list.dart to translate on a phone (then bring the results in
with scripts/import_text_translations.py). Medical meanings stay
English-only and are left out.

Writes one text per line:
    build/texts/en_el.txt   English texts to translate into Greek
    build/texts/el_en.txt   Greek texts to translate into English

    python3 scripts/texts_to_translate.py
"""

from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXTS = ROOT / 'data' / 'texts'
OUT = ROOT / 'build' / 'texts'
FILES = {'en_el': ['en_meanings.csv', 'en_examples.csv', 'en_clues.csv'],
         'el_en': ['el_meanings.csv', 'el_examples.csv', 'el_clues.csv']}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, files in FILES.items():
        texts: dict[str, None] = {}
        for f in files:
            with open(TEXTS / f, newline='', encoding='utf-8') as fh:
                for r in csv.DictReader(fh):
                    t = ' '.join(r['text'].split())
                    if t and not r['translation']:
                        texts.setdefault(t, None)
        path = OUT / f'{name}.txt'
        path.write_text(''.join(t + '\n' for t in texts), encoding='utf-8')
        print(f'{path.relative_to(ROOT)}: {len(texts):,} texts')


if __name__ == '__main__':
    main()
