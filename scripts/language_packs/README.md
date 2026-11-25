# Language packs

Languages the app downloads on request (Settings > Language): today Spanish
(`es`) and German (`de`). English and Greek are built in and aren't packs.

A pack is one download, made of two parts:

- **its dictionary**: one SQLite file with the same tables as the built-in
  `lexicon.db` + `texts.db`, so the app opens it the same way
  (`lib/dictionary_service.dart`);
- **its offline translator** to and from English (OPUS-MT, the same
  ONNX format as Greek's). Another pair, e.g. Spanish ↔ Greek, goes through
  English (`lib/opus_mt_translator.dart`).

What the app may download is in `assets/language_packs.json`, written by
the upload; `lib/language_packs.dart` downloads, checks and removes packs.

## Sources

| Pack | Words | Translator |
|---|---|---|
| es | Multilingual Central Repository via the Open Multilingual Wordnet (CC BY 3.0) | `opus-mt-tc-big-en-es`, `opus-mt-tc-big-cat_oci_spa-en` (CC BY 4.0) |
| de | OdeNet (CC BY-SA 4.0): `.models/odenet/deWordNet.xml` from github.com/hdaSprachtechnologie/odenet | `opus-mt-tc-big-gmw-gmw` (CC BY 4.0): one model both ways, with a `>>deu<<` / `>>eng<<` tag |

The wordnets give the words; definitions and examples come from Princeton
WordNet and are translated with the pack's own model (OdeNet's German
definitions are used where it has them). Subjects come from WordNet, as for
English (`scripts/relabel_subjects.py`). The app credits these in About.

## Making a pack

```bash
# 0. WordNet + OMW for NLTK, the models (see scripts/opus_mt/README.md for
#    export / prune / quantize; prune_onnx.py keeps >>xxx<< tags)
.models/venv/bin/python -c "import nltk; nltk.download('wordnet', download_dir='.models/nltk_data'); nltk.download('omw-1.4', download_dir='.models/nltk_data')"
# 1. translate the English definitions and examples (resumable; ~25 min)
.models/venv/bin/python scripts/language_packs/translate_glosses.py es .models/pruned-big-en-es-int8 --workers 8
.models/venv/bin/python scripts/language_packs/translate_glosses.py de .models/pruned-big-gmw-int8 --workers 8
# 2. build the dictionary -> assets/packs/<lang>.db (not in git)
.models/venv/bin/python scripts/language_packs/build_pack.py es
# 3. upload both parts and write assets/language_packs.json
.models/venv/bin/python scripts/language_packs/upload_language_pack.py es
```

The translations (`data/packs/<lang>/glosses.csv`) are kept in git: they
take the longest to make.
