# Lex Hopper texts — every longer text, with its translation

The second of Lex Hopper's two databases (the first, the words, is in
`data/lexicon/`). These CSV files **are** the texts database. Edit them in a
spreadsheet, save as CSV (UTF-8), then rebuild both databases:

```
python3 scripts/build_databases.py
```

That writes `assets/texts.db` (and `assets/lexicon.db`).

## The files

| File | What's in it |
|---|---|
| `en_meanings.csv`, `el_meanings.csv` | the meanings (definitions) of words and phrases |
| `en_meanings_medical.csv` | the meanings of English medical terms (English only, no translation) |
| `en_examples.csv`, `el_examples.csv` | example sentences ("examples of use") |
| `en_clues.csv`, `el_clues.csv` | crossword clues |
| `en_phrases.csv`, `el_phrases.csv` | phrases of 4 words or more (proverbs, long idioms) |

## Texts (meanings, examples, clues)

| Column | Meaning |
|---|---|
| `id` | the text's number; words in `data/lexicon` point to it. **Leave empty for a new row.** Never change an existing id. |
| `text` | the text, in the file's language |
| `translation` | the text in the other language |
| `source` | where the translation came from: `wordnet` (the linked meaning's definition), `seed` (the old dictionaries), `machine` (a machine translator), or yours — write `Lex Hopper` when you fix one, so it's never replaced |

**Fix a translation:** edit `translation` and set `source` to `Lex Hopper`.
A machine translation is only ever replaced by a newer machine one.

## Long phrases

Phrases of 4+ words, kept here instead of with the words. The columns are
the same as a word's in `data/lexicon` (`phrase` instead of `word`); their
meaning is a text in the meanings file (`meaning_id`), their examples are
in `data/lexicon/entry_examples.csv`, and their main translation is in
`data/lexicon/translations_*.csv`. The Dictionary finds them like words.

## On each phone

What people translate in the Translator is saved on their own phone (it
doesn't come back here).
