#!/usr/bin/env python3
"""Add the Greek label names (data/labels_el.json) to
assets/dictionary_filters.json, next to the English ones:
    "names": {"en": "Law / Legal", "el": "Δίκαιο / Νομικά"}

Runs at the end of the full build (the label scripts rewrite the JSON), and
can be run on its own after editing data/labels_el.json:
    python3 scripts/apply_label_translations.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILTERS_JSON = ROOT / 'assets' / 'dictionary_filters.json'
GREEK = ROOT / 'data' / 'labels_el.json'


def build(_db_path=None) -> None:
    el = json.loads(GREEK.read_text(encoding='utf-8'))
    filters = json.loads(FILTERS_JSON.read_text(encoding='utf-8'))
    missing = []

    def name(label: dict, table: dict) -> None:
        greek = table.get(label['id'])
        if greek is None:
            missing.append(label['id'])
        else:
            label['names']['el'] = greek

    for group in filters.get('subjectGroups', []):
        name(group, el['groups'])
        for subject in group['subjects']:
            name(subject, el['subjects'])
    for usage in filters.get('usageLabels', []):
        name(usage, el['usages'])
    for structure in filters.get('structures', []):
        greek = el['structures'].get(structure['id'])
        if greek is None:
            missing.append(structure['id'])
            continue
        structure['names']['el'] = greek[0]
        structure.setdefault('descriptions', {})['el'] = greek[1]

    FILTERS_JSON.write_text(json.dumps(filters, indent=2, ensure_ascii=False))
    print(f'labels: Greek names added'
          f'{"; missing: " + ", ".join(missing) if missing else ""}',
          file=sys.stderr)


if __name__ == '__main__':
    build()
