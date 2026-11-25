#!/usr/bin/env python3
"""Upload a language pack to Hugging Face and point the app at it: its
dictionary (assets/packs/<lang>.db, gzipped) into the dataset repository
<you>/lex-hopper-data under packs/, its translator (both directions, from
.models/pruned-big-<pair>-int8) into the model repository
<you>/lex-hopper-models under opus-mt/, each pinned to its commit, then
writes the language's entry in assets/language_packs.json.

    .models/venv/bin/python scripts/language_packs/upload_language_pack.py es [--dry-run]

Signed in with a Write token (`.models/venv/bin/hf auth login`).
"""
import gzip, hashlib, json, shutil, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / 'assets/language_packs.json'
FILES = ['encoder_model.onnx', 'decoder_model_merged.onnx', 'source.spm',
         'source_vocab.json', 'target_vocab.json', 'config.json']

# The translator's folders and where they come from: Spanish has a model
# each way; German one multilingual model for both (it takes a tag).
MODELS = {
    'es': [('en-es', 'pruned-big-en-es-int8'),
           ('es-en', 'pruned-big-es-en-int8')],
    'de': [('de-en', 'pruned-big-gmw-int8')],
}

CREDITS = {
    'es': {
        'dictionary': (
            'Spanish words: Multilingual Central Repository (MCR 3.0), via '
            'the Open Multilingual Wordnet — CC BY 3.0. Definitions and '
            'examples: Princeton WordNet 3.0 (WordNet licence), translated '
            'into Spanish with OPUS-MT.'),
        'translator': (
            'Helsinki-NLP/opus-mt-tc-big-en-es (English → Spanish) and '
            'Helsinki-NLP/opus-mt-tc-big-cat_oci_spa-en (Spanish → English), '
            'CC BY 4.0, exported to ONNX, vocabulary trimmed to each side, '
            'weights quantized to 8 bits.'),
    },
    'de': {
        'dictionary': (
            'German words and definitions: OdeNet (Offenes Deutsches '
            'WordNet, Siegel & Bond 2021) — CC BY-SA 4.0. Missing '
            'definitions and the examples: Princeton WordNet 3.0, translated '
            'into German with OPUS-MT. This dictionary is shared under CC '
            'BY-SA 4.0.'),
        'translator': (
            'Helsinki-NLP/opus-mt-tc-big-gmw-gmw (West Germanic languages, '
            'used for English ↔ German both ways), CC BY 4.0, exported to '
            'ONNX, vocabulary trimmed, weights quantized to 8 bits.'),
    },
}


def sha(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def main():
    lang = sys.argv[1]
    dry = '--dry-run' in sys.argv
    db = ROOT / f'assets/packs/{lang}.db'
    if not db.exists():
        sys.exit(f'missing {db} — run build_pack.py {lang} first')
    fingerprint = hashlib.sha1(db.read_bytes()).hexdigest()[:12]

    # The dictionary, gzipped.
    stage = Path(tempfile.mkdtemp())
    (stage / 'packs').mkdir()
    gz = stage / 'packs' / f'{lang}_{fingerprint}.db.gz'
    with open(db, 'rb') as f, gzip.GzipFile(gz, 'wb', compresslevel=9,
                                            mtime=0) as g:
        shutil.copyfileobj(f, g, 1 << 20)
    (stage / 'packs' / f'CREDITS-{lang}.md').write_text(
        CREDITS[lang]['dictionary'] + '\n', encoding='utf-8')
    dictionary = {'path': f'packs/{gz.name}', 'gz_bytes': gz.stat().st_size,
                  'sha256': sha(gz), 'bytes': db.stat().st_size,
                  'fingerprint': fingerprint, 'repo_type': 'dataset'}

    # The translator, both directions.
    models = Path(tempfile.mkdtemp())
    files = []
    for pair, model in MODELS[lang]:
        src = ROOT / f'.models/{model}'
        for name in FILES:
            dest = models / 'opus-mt' / pair / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src / name, dest)
            files.append({'path': f'{pair}/{name}',
                          'bytes': dest.stat().st_size, 'sha256': sha(dest)})
    (models / 'opus-mt' / f'CREDITS-{lang}.md').write_text(
        CREDITS[lang]['translator'] + '\n', encoding='utf-8')
    translator = {'folder': 'opus-mt', 'files': files}

    if not dry:
        from huggingface_hub import HfApi
        api = HfApi()
        user = api.whoami()['name']
        data_repo, model_repo = f'{user}/lex-hopper-data', \
            f'{user}/lex-hopper-models'
        info = api.upload_folder(
            repo_id=data_repo, repo_type='dataset', folder_path=str(stage),
            commit_message=f'Language pack {lang}: dictionary {fingerprint}')
        dictionary.update(repo=data_repo, revision=info.oid)
        info = api.upload_folder(
            repo_id=model_repo, folder_path=str(models),
            commit_message=f'Language pack {lang}: OPUS-MT '
                           f'{", ".join(p for p, _ in MODELS[lang])}')
        translator.update(repo=model_repo, revision=info.oid)
    else:
        dictionary.update(repo='', revision='')
        translator.update(repo='', revision='')

    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    if not dry:
        manifest[lang] = {'dictionary': dictionary, 'translator': translator}
        MANIFEST.write_text(json.dumps(manifest, indent=1) + '\n',
                            encoding='utf-8')
    total = dictionary['gz_bytes'] + sum(f['bytes'] for f in files)
    print(f'{lang}: {total / 1e6:.0f} MB to download '
          f'(dictionary {dictionary["gz_bytes"] / 1e6:.0f} MB) — '
          f'{"uploaded" if not dry else "dry run: not uploaded"}')


if __name__ == '__main__':
    main()
