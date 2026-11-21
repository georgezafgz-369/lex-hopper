# Dictionary — what we could add next

Written 17 Nov 2026. The app will be sold (≈ €0.70) or carry ads, so every
source must allow **commercial use without share-alike** (no CC BY-SA, no
copyrighted dictionaries such as Apple/Oxford, Etymonline or Merriam-Webster).

Also done 17 Nov: **word links** (related adjectives, tooth → dental) from WordNet. Word origins skipped for now (no free source that allows selling).

Where we are now: WordNet 3.0 (full), the medical lists, ICD-10, 239 grammar
words and 950 hand-written idioms / phrasal verbs / proverbs — 496,479
entries, 101 MB, version 12.

---

## 1. Quick wins — no download, our own work

| # | What | How | Effort |
|---|------|-----|--------|
| 1 | ✅ **Done 17 Nov — Word forms** (run → ran, running; mouse → mice; good → better, best) shown on the word page | WordNet's exception lists (already in `data/wordnet`) + spelling rules | Small |
| 2 | **Idiom labels for the rest of WordNet's idioms** (*pull a fast one on*, *stand fast*) | Detect multi-word entries with "one's", "someone", "it", articles, and review the list by hand | Small–medium |
| 3 | **Anagrams** ("listen" → silent, enlist, tinsel) on the word page | Computed from the word list — no data needed; great for a word-game app | Small |
| 4 | **Example sentences for common words that have none** | Write our own for the ~2,000 most common words without examples (like the phrase lists) | Medium |
| 5 | **More idioms / sayings** for common words that have few (*fast*, *eye*, *cat*) | Extend `data/phrases/*.txt` | Medium, ongoing |
| 6 | **Confusable words** (affect / effect, their / there / they're) as a "Don't confuse with" note | Hand-written list of ~200 pairs | Small |

## 2. Free sources that allow commercial use

| # | What | Source & license | Effort |
|---|------|------------------|--------|
| 7 | ✅ **Done 17 Nov — Pronunciation** (IPA, e.g. \|wərd\|) and **syllables** | CMU Pronouncing Dictionary — BSD-style, free for commercial use; ~134,000 words; convert ARPAbet → IPA | Medium |
| 8 | **Rhymes** ("word" → bird, heard, third) | Computed from the CMU pronunciations (needs #7) | Small after #7 |
| 9 | **US / UK spellings** (color / colour, organize / organise) | VarCon from SCOWL — permissive license (check the exact terms before use) | Small |
| 10 | **How common a word is** (a "Common / Rare" badge, better crossword difficulty) | Our own ranking from WordNet definitions (already used for puzzles); Google Books Ngram counts are CC BY 3.0 (attribution only) if we want more accuracy | Small–medium |

## 3. Bigger projects (decide later)

| # | What | Notes |
|---|------|-------|
| 11 | ✅ **Done 18 Nov — Greek dictionary** (Greek words and Greek definitions, not translations) | Greek WordNet from the Open Multilingual Wordnet — Apache 2.0. Still to do: Greek crosswords (word counts: Leipzig Corpora Collection, CC BY 4.0). Wiktionary is CC BY-SA (not usable). |
| 12 | **Full word origins** ("Old English, of Germanic origin…") | No free commercial source covers this well. Option: write short origins ourselves for the top ~500 words. |
| 13 | **Encyclopedia summaries** (like the Wikipedia section in the Mac Dictionary) | Wikipedia text is CC BY-SA — not usable as stored data. Could link out to Wikipedia instead (needs internet). |

## 4. Before release

- ✅ Checked 17 Nov: a **release APK** is ~53–57 MB per phone type (debug is 227 MB). Fresh install: the dictionary copy takes ~0.6 s, "Loading dictionary…" shows for ~3 s, no freeze. (The "isn't responding" seen on the emulator happens only with debug builds, which also unpack ~100 MB of debug code on first launch.)
- Remove the temporary **"Next level (test)"** button from the crossword (`lib/crossword_game_page.dart`, marked TODO).
- Set the real **feedback email address** (`feedbackEmail` in `lib/app_settings.dart`, now the placeholder `feedback@example.com`).
- Add an **About / credits** screen: Princeton WordNet licence notice, the CMU Pronouncing Dictionary copyright notice (required by its BSD licence; text in `data/licences/cmudict_LICENSE.txt`), NCI Thesaurus / ontology credits, ICD-10 (WHO) terms of use, the Greek WordNet (Apache 2.0: include its licence text, `data/licences/greek_wordnet_LICENSE.txt`), Wikidata lexemes (CC0, no credit needed but nice to mention), the Leipzig Corpora Collection (CC BY 4.0: "Leipzig Corpora Collection: Greek news corpus based on material from 2023") — check that each medical source allows commercial redistribution.

---

### Suggested order

1. Word forms (#1) and anagrams (#3) — quick, visible, no download.
2. Pronunciation + rhymes (#7, #8) — the biggest gap compared with the Mac Dictionary.
3. Idiom labels (#2) and confusable words (#6).
4. Licence/credits check and a release build (section 4) — before publishing.
5. Examples and more phrases (#4, #5) — ongoing.
6. Translations (#11) — once a licence-safe source is found.
