#!/usr/bin/env python3
"""Fill the translations of data/texts/*.csv from the files made by
a machine translator ("text<TAB>translation" lines): English texts
translated into Greek (en_el.tsv) and Greek texts into English (el_en.tsv).

Only empty translations, or ones a previous import put there (source
"machine"), are filled; any other translation (from WordNet, the seed, or
fixed by hand) is kept.

    python3 scripts/import_text_translations.py en_el.tsv el_en.tsv
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEXTS = ROOT / 'data' / 'texts'
# Medical meanings stay English-only: their machine translations were the
# weakest and took the most space, so they are not imported.
FILES = {'en': ['en_meanings.csv', 'en_examples.csv', 'en_clues.csv'],
         'el': ['el_meanings.csv', 'el_examples.csv', 'el_clues.csv']}


def read_tsv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        text, tab, tr = line.partition('\t')
        if tab and text.strip() and tr.strip():
            out[' '.join(text.split())] = tr.strip()
    return out


def fill(path: Path, machine: dict[str, str]) -> tuple[int, int]:
    with open(path, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        columns = reader.fieldnames
        rows = list(reader)
    added = 0
    for r in rows:
        if r['translation'] and r['source'] != 'machine':
            continue
        tr = machine.get(' '.join(r['text'].split()))
        if tr and (r['translation'], r['source']) != (tr, 'machine'):
            r['translation'], r['source'] = tr, 'machine'
            added += 1
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=columns)
        w.writeheader()
        w.writerows(rows)
    return added, sum(1 for r in rows if not r['translation'])


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    machine = {'en': read_tsv(Path(sys.argv[1])),
               'el': read_tsv(Path(sys.argv[2]))}
    for lang, names in FILES.items():
        for name in names:
            added, left = fill(TEXTS / name, machine[lang])
            print(f'{name}: {added:,} translations added, '
                  f'{left:,} still without one')


if __name__ == '__main__':
    main()
