# Lex Hopper — Page Structure

> **Where the words come from now (Nov 2026).** Every page reads Lex
> Hopper's own two databases, `assets/lexicon.db` (words and short phrases,
> their links and main translations) and `assets/texts.db` (meanings,
> example sentences, crossword clues and long phrases, each with its
> translation), through `DictionaryService`. Both are built by
> `scripts/build_databases.py` from our CSV files in `data/lexicon/` and
> `data/texts/` (see their READMEs). The Translator also keeps the texts
> people translate on their own phone (`my_texts.db`, `saved_translations.dart`).
> The old dictionaries (`dictionary.db`, `dictionary_el.db`), the scripts
> that built them and their source files (WordNet, the Greek WordNet, CMU,
> Wikidata, Leipzig, our old word lists) were removed; where the notes below
> name them, they tell where the data first came from. Their licences and
> the credits they ask for are in `data/licences/`.

## Route Map

```
/              → HomePage
/crossword     → CrosswordMenuPage
/crossword/game → CrosswordGamePage
/word-search   → WordSearchMenuPage (→ WordSearchGamePage, pushed directly)
/dictionary    → DictionaryPage
/settings      → SettingsPage
```

---

## 1. HomePage (`/`)
**File:** `lib/home_page.dart`

The main "Puzzle Page" — a scrollable list of game cards.

### Layout (top → bottom)
| Section | Description |
|---------|-------------|
| **Top bar** | Search bar (placeholder "Search dictionary...") + Home button. Typing a word and pressing the keyboard's search key opens the Dictionary page with that word searched (the bar then clears) |
| **"GAMES" kicker** | Section label |
| **Game cards** | Crossword, Find the Words, Riddles |
| **Divider** | Hairline separator |
| **"REFERENCE" kicker** | Section label |
| **Dictionary card** | Dictionary reference |
| **Divider** | Hairline separator |
| **"OTHER" kicker** | Section label |
| **Other cards** | Settings |

### Cards by Section
Cards show only a title and a subtitle (no red kicker label); unfinished games show a "Coming soon" tag beside the title.

#### Games
| Card | Navigates To |
|------|-------------|
| Crossword | `/crossword` |
| Find the Words | *(none yet)* — "Coming soon" tag |
| Riddles | *(none yet)* — "Coming soon" tag |

#### Reference
| Card | Navigates To |
|------|-------------|
| Dictionary | `DictionaryPage` (via MaterialPageRoute) |

#### Other (not games)
| Card | Navigates To |
|------|-------------|
| Settings | `/settings` — Language, Dark mode, Font size |

---

## 2. CrosswordMenuPage (`/crossword`)
**File:** `lib/crossword_menu_page.dart`

Menu for starting or continuing a crossword game.

### Layout (top → bottom)
| Section | Description |
|---------|-------------|
| **Top bar** | Back button (←) + Home button |
| **Header** | "DAILY CROSSWORD" kicker → "Crossword" title |
| **New Game card** | "New Game" / "Start a fresh puzzle." → clears save, navigates to `/crossword/game` |
| **Continue card** | "Continue" / "Pick up where you left off — No. X." or "No saved game." → loads saved state |

### State
- Checks `CrosswordSave.hasGame()` on init
- Continue card is disabled when no saved game exists

---

## 3. CrosswordGamePage (`/crossword/game`)
**File:** `lib/crossword_game_page.dart`

The main crossword puzzle screen with grid, clues, and action buttons.

### Layout (top → bottom)
| Section | Description |
|---------|-------------|
| **Top bar** | Level indicator (left) · compact "Search on dictionary" button with a book icon (centre) · Home button (right) |
| **Level indicator** | "Level One", "Level Two", etc. (kicker style) |
| **Grid** | Dynamic NxN grid of cells, no background fill or outline border — sits directly on the page background. Tap a cell to select it and open the keyboard. Letters fill in. States: normal, selected, correct (green ✓), wrong (red ✗) |
| **ACROSS CLUES / DOWN CLUES** | Header buttons that switch the clue list |
| **Clue list** | Numbered clues in a card container. One tap selects that word and closes the keyboard if it's open; only a double tap selects it and opens the keyboard. Once a word is confirmed correct (every cell green, by Check or by solving the puzzle), its clue ends with the answer in brackets, e.g. **[SEARCH]** (bold, ink colour — black in light mode, cream in dark mode); tapping it opens that word's page from the bottom |
| **Action buttons** | One row: Clear · Hint, please · Check |
| **Next level (test)** | TEMPORARY, for testing higher levels: skips to the next level without solving. Shown to everyone (also in release builds) — remove before publishing |

### Actions
| Button | Behavior |
|--------|----------|
| **Check** | Validates the current word against the answer |
| **Hint, please** | Reveals the first unrevealed letter |
| **Clear** | Double tap clears all letters in the current word; a single tap only shows "Double-tap Clear to erase this word." |
| **Search on dictionary** | Opens the dictionary as a bottom sheet (opens at 60% height; drag it to any height from 25% to full and it stays there; closes with the X at top right, the phone's Back button, or by pulling it on down from 25% — let go below 17% or flick it down; a shorter pull springs back to 25%). Word pages use the same sheet, pre-searched with the letters typed in the selected word (`_` for blanks) |

### State
- `userLetters`: Map of user input per cell
- `cellStates`: correct / wrong / empty per cell
- Saves state to `CrosswordSave` after every input
- Receives `resumeState` from menu to restore progress

### Data Models
- `GridCell` — row, col, isBlack, clueNumber, answer
- `Clue` — number, text, cells
- `CrosswordPuzzle` — level, cols, rows, grid, across clues, down clues

### Puzzle generation

**Phrases (Level 5+):** `puzzle_words` also holds 1,829 everyday phrases (`phrase = 1`): our idioms / phrasal verbs / proverbs plus two-word WordNet entries made of two common words (ice cream, fast food), at most 9 cells long. From Level 5 the maker adds ~30 of them to the pool and the generator tries up to two first. In the answer the space is stored as `#` (`phraseGap`, e.g. `STEP#OUT`); it becomes a solid ink square in the grid (`GridCell.isGap`) that no other word may cross, typing skips it, and the solved answer shows as **[STEP OUT]**. Clues don't show word lengths.
**Files:** `lib/crossword_puzzle.dart` (model, difficulty, layout), `lib/crossword_maker.dart` (dictionary + no-repeat)

- Every new puzzle is built from the dictionary's `puzzle_words` table (made by `scripts/build_puzzle_words.py`): general-domain words, each with a definition as its clue and a commonness rank.
- **New Game** always starts at Level 1. Solving every word (all checked correct) shows "Level X solved" and moves to the next level automatically.
- The exact same set of words is never served twice (last 1,000 sets remembered); single words may repeat.
- The puzzle is saved with the progress, so **Continue** restores the same grid.

| Level | Grid | Words | Length | Word ranks (1 = most common) |
|-------|------|-------|--------|------------------------------|
| 1 | 5×5 | 4 | 3–5 | 1 – 1,500 |
| 2 | 6×6 | 6 | 3–6 | 1 – 3,000 |
| 3 | 7×7 | 8 | 3–7 | 1,500 – 6,000 |
| 4 | 8×8 | 9 | 4–8 | 3,000 – 12,000 |
| 5 | 9×9 | 11 | 4–9 | 6,000 – 24,000 |
| 6 | 10×10 | 12 | 4–10 | rarer |
| 7 | 11×11 | 13 | 5–11 | rarer |
| 8 | 12×12 | 15 | 5–11 | rarer |
| 9+ | 13×13 | 17 | 5–11 | rarer each level |

The word counts are what each grid size usually holds. The maker looks for up to 1.5 s and keeps the best layout found. A grid whose squares would be smaller than 40 points on the screen (from about level 6 on a phone) sits in a window you can drag and pinch-zoom like a map; it follows the selected square.

---

## 3b. Find the Words (`/word-search`)

**Menu** (`word_search_menu_page.dart`): kicker "HIDDEN WORDS", title "Find the Words", **New Game** (clears the save, starts at Level 1) and **Continue** ("Pick up where you left off — No. X." or "No saved game."). It reloads the save when you come back from a game.

**Game** (`word_search_game_page.dart`): top bar with the level and Home; the letter grid (a white card as wide as the page); "WORDS TO FIND" with "X of Y found"; the word chips. Drag from a word's first letter to its last (either way round); the line snaps to straight directions. While a finger is on the grid the page doesn't scroll, so drags always select letters. A listed word stays marked by a rounded band in the next of five highlighter tints (`AppColors.ws*`, a little see-through so crossing words blend) and its chip gets the same tint (no strike-through). All found → "All words found!" with **Next level**. **Next level (test)** (until solved) skips ahead — remove before publishing. Tapping a found word's chip opens its word page. With a secondary language that is the other one (English ↔ Greek), each chip shows the word's translation in slate blue (`puzzle_words.word_tr`, from the other WordNet's first word for the clue's synset, filled by `scripts/build_clue_translations.py`, and only when that clue is the word's main meaning — English: most used in WordNet's tagged texts, Greek: first-listed meaning — so BEHIND isn't shown as γλουτοί; about a third of the 3,000 most common English answers and 60% of the Greek ones have one). Letters are painted at a fixed size, whatever the phone's text size.

**Puzzles** (`word_search_puzzle.dart`, `word_search_maker.dart`): words read forwards only (never backwards) and each appears exactly once that way; words containing another listed word aren't used together; filler letters follow the hidden words' own letter mix. Words come from the crossword's `puzzle_words` lists (same commonness windows per level, except English stops at the 12,000 most common words — ranks 3,000–12,000 from level 4 — because the list shows bare words with no clue); Greek uses capitals without accents. The same set of words is never served twice (last 1,000 remembered, per language).

| Level | Grid | Words | Directions |
|-------|------|-------|------------|
| 1–2 | 6×6, 7×7 | 5, 6 | across, down |
| 3–4 | 8×8, 9×9 | 8, 10 | + diagonal down-right |
| 5 | 10×10 | 12 | + diagonal up-right |
| 6 | 11×11 | 14 | all four |
| 7+ | 12×12 | 15 | all four |

**Saving** (`word_search_save.dart`): one game per language (`word_search_save` / `word_search_save_el`): the puzzle and the found words with their tints, saved after each found word and when a level starts.

---

## 3c. Subjects for new games (both games)

**New Game** in either menu first opens **Choose a subject** (`theme_picker.dart`, a draggable sheet): **All subjects** (every answer, as before), then the themes with at least 60 answers in the game's language, each with its word count. English offers all 18; Greek the 9 biggest (Animals, Plants & Gardens, Food & Drink, Body & Health, Law & Politics, Money & Business, Earth & Places, Religion & Myth, Travel & Transport). Closing the sheet starts nothing.

Themes (`puzzle_themes.dart`): Animals, Plants & Gardens, Food & Drink, Body & Health, Earth & Places, Science, Money & Business, Mind & Society, Law & Politics, Travel & Transport, Tech & Numbers, Religion & Myth, Arts & Books, War & History, Fashion, Music, Language, Sports & Games.

An answer's theme is `puzzle_words.theme`, filled by `scripts/build_puzzle_themes.py` (run after rebuilding the puzzle lists). The meaning its clue comes from must clearly belong: WordNet puts it in a matching group (noun.animal, noun.food, noun.body…), or links it to a matching topic (sharp → music, Zeus → mythology), or the dictionary's subject label matches **and** the clue mentions the theme (a music answer's clue says song, melody…). Labels alone were too loose ("a charge of ammunition" was labelled music). Greek answers always need the clue check, because the Greek WordNet sometimes ties a word to the wrong meaning.

Levels work as usual, within the theme: its answers sorted most common first; level 1 takes the first eighth (at least 120), each level doubles that, and from level 3 the most common quarter is left out (`themeWindow`). The theme is saved with the game, kept for every next level, and shown on Continue ("Pick up where you left off — No. 4, Music.").

---

## 4. DictionaryPage (`/dictionary`)
**File:** `lib/dictionary_page.dart`

Search and browse dictionary entries with filters.

### Layout (top → bottom)
| Section | Description |
|---------|-------------|
| **Top bar** | Back button (←) + Search bar + Home button |
| **Filters** | "PART OF SPEECH" chips (Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Interjection, Determiner) + "STRUCTURE" chips (Simple / Compound / Derived) + a "SUBJECT" selector that opens a list of the 8 subject groups (expand a group to pick one of its 76 subjects, with word counts). With the search box empty, the whole dictionary (or just the words matching the filters) is listed A–Z, one card per word with its meaning count, 100 at a time as you scroll; words starting with a number or symbol come after Z. Typed searches stay shortest first. |
| **Content area** | Loading spinner / Empty state icon + text / Search results list |

**Scrolling:** the whole page is one `CustomScrollView`. The search bar row is a pinned header (`_PinnedBar`) that always stays at the top; the filters and the results scroll together beneath it. In the bottom sheet, dragging anywhere (search bar and filters included) first grows the sheet to full height, then scrolls.

### Entry Card (in results list)
| Element | Description |
|---------|-------------|
| **Word** | Italic, bold |
| **POS badge** | e.g. "NOUN" in clay color |
| **Label tags** | Under the word: subject as a filled tag (e.g. "Culinary & Cooking"), usage and loanword origin as outlined italic tags (e.g. *Slang*, *From Yiddish*) |
| **Meaning preview** | First ~120 characters; pressing the card opens the word page |
| **Word page** (`lib/word_sheet.dart`) | Under the title: pronunciation |IPA|, syllables and two speaker buttons, **🔊 US** and **🔊 UK**, that say the word with the phone's own text-to-speech voice (`lib/speech.dart`, flutter_tts; a short message if that accent's voice isn't installed). Bottom sheet (same sheet as above: free height, X to close) with every meaning of the word grouped by part of speech and numbered (most common first), the pressed meaning highlighted, subject/usage tags, example sentences, synonyms and opposites per meaning, then "Phrases" (multi-word entries containing the word) and "About the word" (structure, origin, related forms). Pressing a synonym opens that word's page as another sheet on top |

### State
- Debounced search (300ms)
- Filters: partOfSpeech, structure, subject (labels from `assets/dictionary_filters.json`, names per language — English only so far; tagged by `scripts/build_subject_labels.py`; structure, synonyms and origin by `scripts/build_word_types.py`; pronouns, prepositions, conjunctions, interjections and determiners are hand-written entries in `scripts/build_function_words.py`; `scripts/build_phrases.py` adds ~950 idioms, phrasal verbs and proverbs written for Lex Hopper (`data/phrases/*.txt`, own definitions and examples, no license strings; "one's" phrases are also findable with "your") and labels WordNet's existing phrases and phrasal verbs, shown as the Idiom / Phrasal Verb / Proverb usage tags; `scripts/build_word_info.py` adds pronunciation + syllables (CMU Pronouncing Dictionary in `data/cmudict`, BSD — credit CMU in the app), word forms (`word_forms`: plural / verb forms / comparatives, irregulars from `data/forms/*.txt`) and word links (`word_info.adjectives`: tooth → dental, from WordNet pertainyms), shown on the word page under the title, under each part-of-speech heading and in "About the word"; the last build step, `scripts/compact_db.py`, stores repeated text once (table `texts`) and drops the filter indexes — the app reads the `entries` view, which has the same columns as before (166 MB -> 101 MB); `scripts/build_medical.py` adds `medical_phrases_and_meanings.csv` (main terms as entries, other names in the `aliases` table — search finds an entry through its aliases, the card says "Also called …" and the word page lists them), every ICD-10 diagnosis as an entry with its code (shown as a tag, e.g. "ICD-10 A00.0"), and the xlsx use cases ("More examples" on the word page); medical categories map to Health & Medicine subjects and abbreviations get the Abbreviation usage label; `scripts/build_wordnet.py` adds the full Princeton WordNet 3.0 (raw files in `data/wordnet/`, not bundled): the meanings the CSV cut, multi-word entries, examples, antonyms, related forms and sense order; medical entries arrive without a part of speech, so `scripts/fix_parts_of_speech.py` re-labels the ones defined as adjectives or adverbs, e.g. dorsal, rapidly)
- Entry cards open the word page (`showWordSheet`)
- Uses `DictionaryService` for database queries

---

## 5. SettingsPage (`/settings`)

**File:** `lib/settings_page.dart` (saved values: `lib/app_settings.dart`)

| Element | Description |
|---|---|
| **Top bar** | Back button + HomeButton |
| **Header** | "PREFERENCES" kicker + "Settings" title |
| **Font size card** (below Dark mode) | Small · Medium · Large buttons (each label shown in its own size; active one filled clay). Scales all text in the app on top of the phone's own text size (0.85× / 1× / 1.2×, via `MaterialApp.builder`); the crossword grid letters opt out (`MediaQuery.withNoTextScaling`) so they always fit. Saved as `settings_font_size` |
| **Language card** | Shows the current language; opens a sheet listing English (selectable, ticked) and Ελληνικά / Español / Français / Deutsch / Italiano as "Coming soon" |
| **Dark mode card** | On/off switch (the whole card also toggles). Until first used it shows what the phone uses and the app follows the phone; after that the app is always dark or always light |
| **Separator** | Hairline divider below Dark mode |
| **Feedback card** | Opens the phone's email app with a new message to `feedbackEmail` (`lib/app_settings.dart`, placeholder `feedback@example.com` — set the real address before release), subject "Lex Hopper feedback"; shows the address if there's no email app (url_launcher, `mailto` query in AndroidManifest) |
| **About the app card** | "About the app" — moved here from the home page (was "About Us"); no page behind it yet |

### State
- `AppSettings.instance` (ChangeNotifier): `darkMode` (bool?, null = follow the phone), `language` (code, `en`), `fontSize` (`FontSizeOption`, medium)
- Saved in SharedPreferences (`settings_dark_mode`, `settings_language`) and loaded in `main()` before the first frame
- `MaterialApp.themeMode` rebuilds from it, so the whole app switches at once

---

## Languages (English / Greek)

- **App text:** every visible text lives in `lib/app_text.dart` (`AppText.of(context).newGame`), each in English and Greek. Greek is written naturally in the app's voice, not word for word. `AppText.upper()` makes Greek capitals without accents (ΟΥΣΙΑΣΤΙΚΟ).
- **Choosing:** Settings > Language (`AppSettings.language`, saved as `settings_language`). Until the user picks one, the app follows the phone: Greek if the phone is Greek, otherwise English. `MaterialApp.locale` + `GlobalMaterialLocalizations.delegates` (from material_ui) also translate the built-in texts.
- **Main and secondary language:** tapping an available language in Settings > Language offers "Set as main language" / "Set as secondary language" (or "Remove as secondary language"). The list shows the main language first (tag Κύρια/Main), then the secondary (tag Δευτερεύουσα/Secondary), then the rest. Making the secondary the main one swaps them; the secondary is optional (`AppSettings.secondaryLanguage`, saved as `settings_secondary_language`). The Language card reads e.g. "Ελληνικά · δευτερεύουσα: English". With a secondary language, texts show their translation, smaller and grey: card titles and section labels right next to them on the same line (`DualText(..., inline: true)`), descriptions and tags on a line underneath (`DualText((t) => t.crossword, style: …)` in `lib/dual_text.dart`); one-line places like the search hint use `dualString` → "Search dictionary... (Αναζήτηση στο λεξικό...)". Applied on every page: Home, Settings, Crossword menu and game (buttons, clue tabs, level, messages), Dictionary (filters, badges, counts) and the word page (headings, facts, chips). Language names are written in the main language with the secondary one's name next to them (`AppText.languageName`). Crossword clues show their translation (English ↔ Greek) on a small grey line underneath when the secondary language is the other one: `puzzle_words.clue_tr`, filled by `scripts/build_clue_translations.py` (run it after rebuilding either puzzle list), which matches each clue to its WordNet synset and takes the Greek WordNet / Princeton WordNet definition of that synset. About half the English clues and three quarters of the Greek ones have one; the others show the clue alone. Still in the main language only: subject/usage tags and dictionary content (definitions, examples).
- **Dictionary labels:** Greek names for the 8 groups, 76 subjects, 19 usage labels and 3 structures are in `data/labels_el.json`, merged into `assets/dictionary_filters.json` by `scripts/apply_label_translations.py` (part of the full build). Parts of speech and level names ("Επίπεδο Δύο") are in `app_text.dart`.
- **Greek dictionary:** in Greek the Dictionary page and word page read `assets/dictionary_el.db` (`DictionaryService.greek`; `DictionaryService.forLanguage(code)` picks it). About 16,400 words and 22,300 meanings with Greek definitions, synonyms, opposites, related forms and subject labels, built by `scripts/build_greek_dictionary.py` from the Greek WordNet (Apache 2.0, `data/wordnet_el/`). Search and A–Z order ignore accents and capitals (`greekPlain`: σπίτι = σπιτι). In Greek there's no Structure filter; the part-of-speech filter has the 10 of Greek grammar (Άρθρο and Μετοχή are Greek only: `art`, `part`). Articles, pronouns, prepositions, conjunctions, interjections, participles and ~180 common adjectives/adverbs come from our own lists in `data/words_el/*.txt` (`pos|word|meaning|example`). `common_*.txt` are everyday words the WordNet lacked, picked with `scripts/greek_wikidata.py` (Wikidata lexemes, CC0, `data/wikidata_el/`; ranked by news counts, skipping any word we already have), definitions written by us. Noun plurals ("πληθυντικός: σπίτια") come from the Wikidata forms. and one ΕΛ voice button (el-GR) in place of US/UK. Greek idioms and proverbs: our own list, `data/phrases_el/*.txt` (`pos|phrase|meaning|example`, ~260 idioms + ~80 proverbs), labelled Idiom/Proverb with an example each; short ones are crossword phrases from Level 5. Otherwise Greek has no example sentences, word forms or pronunciation yet. The device copy is `dictionary_el_v1.db`; bump it when the Greek DB changes.
- **Greek crosswords:** a game started in Greek uses `puzzle_words` of the Greek DB (built by `scripts/build_greek_puzzle_words.py`): ~5,350 answers in capitals without accents (ΣΠΙΤΙ) with Greek clues, ranked by Greek news word counts (Leipzig, CC BY 4.0). Levels use `LevelSettings.forLevel(level, poolSize:)` (windows from 1,000, doubling). Typing accepts Greek letters with or without accents (ά -> Α) on the normal text keyboard. English and Greek games are saved apart (`crossword_save` / `crossword_save_el`); a game keeps its language. Solved answers open the Greek word page (ΣΠΙΤΙ -> σπίτι).

## Shared Components

### HomeButton (`design_system.dart`)
- Clay-colored square button with home icon
- One tap navigates to `/` (HomePage), clearing the stack
- Appears on every page's top bar

### Design System (`design_system.dart`)

Full guide (colours, puzzle states, type, layout, motion, tone of voice, logo): `docs/design-package.pdf`.
| Token | Light | Dark |
|-------|-------|------|
| Paper (background) | `#FBF3E8` | `#1B1815` |
| Grid Cell (cards) | `#FFFDF8` | `#26221C` |
| Ink (text) | `#201B17` | `#F1E9DD` |
| Muted | `#6B6258` | `#A39A8D` |
| Hairline (borders) | `#CFC2AE` | `#4A4338` |
| Clay (accent) | `#C8613F` | `#E08A66` |
| Olive | `#3F5A3C` | `#8FDB0A` |
| Claret | `#8F1D3F` | `#D4637F` |

### Typography
- **Headlines:** Source Serif 4 (40 / 28 / 20px)
- **Body:** Source Serif 4 (16 / 14 / 12px, line-height 1.5)
- **UI / Grid:** Inter (semibold, 16 / 14 / 12px)

### Spacing (8pt grid)
`xs: 4` · `sm: 8` · `md: 16` · `lg: 24` · `xl: 32` · `xxl: 48`

### Border Radius
`none: 0` · `sm: 8` (cards, buttons, search bars) · `md: 8` · `lg: 16` (bottom-sheet top corners). Crossword grid squares keep 1 px corners so the grid still looks printed

---

## Navigation Flow

```
HomePage
  ├─→ CrosswordMenuPage ──→ CrosswordGamePage ──⇡ Dictionary sheet
  ├─→ WordSearchMenuPage ──→ WordSearchGamePage
  ├─→ DictionaryPage
  └─→ SettingsPage ──⇡ Language list sheet

CrosswordGamePage ──⇡ Dictionary sheet  (bottom sheet via "Search on dictionary")

HomeButton (any page) ──→ HomePage  (one tap, clears stack)
```
