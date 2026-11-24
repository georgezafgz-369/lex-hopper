# Lex Hopper lexicon — our own English–Greek word database

The first of Lex Hopper's two databases: words and short phrases (up to 3
words; medical names of any length). Longer texts — meanings, example
sentences, crossword clues, phrases of 4+ words — are in the second one,
`data/texts/` (see its README).

These CSV files **are** the lexicon. Open them in Excel, Numbers or any
spreadsheet, edit, save as CSV (UTF-8), then rebuild both databases:

```
python3 scripts/build_databases.py
```

That writes `assets/lexicon.db` and `assets/texts.db`, which the Dictionary,
the Translator and the games all read. The build checks every row and, if
something is wrong, prints the file and line to fix (nothing is written
then).

The files were made once from the app's old dictionaries (WordNet, the
Greek WordNet, medical ontologies and our own lists); everything they held
was checked to have come across. The old dictionaries and the scripts that
made them are gone: these CSV files are the only source now.

## The files

| File | What's in it |
|---|---|
| `entries_en/a.csv` … `z.csv`, `other.csv` | English words and phrases, by first letter |
| `entries_en_medical/…` | English medical terms (kept apart: there are 200,000 of them) |
| `entries_el.csv` | Greek words and phrases |
| `entry_examples.csv` | which example sentences (in `data/texts`) belong to which entry, in order |
| `links.csv` | which English meaning goes with which Greek meaning |
| `translations_en.csv` | the main Greek translation of each English word or phrase |
| `translations_el.csv` | the main English translation of each Greek word or phrase |
| `aliases_en.csv`, `aliases_el.csv` | other names that find an entry (abbreviations, old spellings) |
| `word_info_en.csv` | pronunciation (IPA), syllables, "relating to" adjectives |
| `word_forms_en.csv`, `word_forms_el.csv` | plurals, verb forms |
| `word_examples_en.csv` | extra example sentences (text ids) |
| `puzzle_words_en.csv`, `puzzle_words_el.csv` | crossword / Find the Words answers; `clue_id` is the clue in `data/texts` |

## Entries (one row per meaning)

| Column | Meaning |
|---|---|
| `id` | the entry's number. **Leave empty for a new row** — the build gives it one. Never change an existing id (links point to it). |
| `word` | the word or phrase: `house`, `calm down`, `σπίτι` |
| `type` | `word`, `phrase`, `phrasal verb`, `idiom` or `proverb` (empty = word or phrase, guessed from spaces) |
| `pos` | part of speech: `noun`, `verb`, `adj`, `adv`, … |
| `sense` | 1 = the word's most common meaning, 2 = next, … |
| `meaning_id` | the meaning's text in `data/texts/<lang>_meanings.csv` (several words with the same meaning share it) |
| `synonyms`, `antonyms`, `related` | comma-separated words |
| `origin`, `category`, `subject`, `usage`, `structure`, `code` | labels shown in the Dictionary (may be empty) |
| `domain` | `general` or `medical` |
| `source` | where the row came from (`WordNet`, `Lex Hopper`, …) |

**Add a word:** a new row with an empty `id`, the `word` and `pos`, and its
meaning — either the `meaning_id` of an existing meaning, or the text itself
in a `meaning` column (add that column if the file has none); the build puts
it in the texts. The rest can stay empty. **Fix a meaning:** edit its row.
**Remove one:** delete the row (and any `links.csv` rows with its id).

## Links

`en_id,el_id,source` — an English entry id and a Greek entry id that mean
the same thing. Add a row to connect two meanings; delete one to undo a
wrong link.

## Main translations

`word,translation,source` — what the Translator shows for that word or
phrase. Seeded with a machine translator (`source` = `machine`); fix any
row and set its `source` to `Lex Hopper` so it's clear it was checked.
