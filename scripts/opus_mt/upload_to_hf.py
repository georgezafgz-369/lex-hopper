#!/usr/bin/env python3
"""Upload the offline translator's models to Hugging Face and point the app
at them. Run after making the models (README.md here), signed in with a
Write token (`.models/venv/bin/hf auth login`):

    .models/venv/bin/python scripts/opus_mt/upload_to_hf.py [--dry-run]

Puts .models/pruned-big-{en-el,el-en}-int8 into the public model repository
<you>/lex-hopper-models under opus-mt/, with a model card (CC-BY-4.0,
credit to Helsinki-NLP), then writes assets/opus-mt/manifest.json: the
repository, the commit to download from, and each file's size and SHA-256.
"""
import hashlib, json, shutil, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPO_NAME = 'lex-hopper-models'
FOLDER = 'opus-mt'
SOURCES = {'en-el': ROOT / '.models/pruned-big-en-el-int8',
           'el-en': ROOT / '.models/pruned-big-el-en-int8'}
FILES = ['encoder_model.onnx', 'decoder_model_merged.onnx', 'source.spm',
         'source_vocab.json', 'target_vocab.json', 'config.json']
MANIFEST = ROOT / 'assets/opus-mt/manifest.json'

CARD = """---
license: cc-by-4.0
language: [en, el]
tags: [translation, marian, opus-mt, onnx]
pipeline_tag: translation
base_model:
- Helsinki-NLP/opus-mt-tc-big-en-el
- Helsinki-NLP/opus-mt-tc-big-el-en
---

# Lex Hopper models

Models the Lex Hopper app downloads to work offline.

## opus-mt/ — English ↔ Greek translation

Smaller versions of Helsinki-NLP's OPUS-MT "tc-big" models (CC-BY-4.0), run
on phones with ONNX Runtime:

| Folder | Original model (commit) |
|---|---|
| `opus-mt/en-el` | [Helsinki-NLP/opus-mt-tc-big-en-el](https://huggingface.co/Helsinki-NLP/opus-mt-tc-big-en-el) (`bb9aa4d`) |
| `opus-mt/el-en` | [Helsinki-NLP/opus-mt-tc-big-el-en](https://huggingface.co/Helsinki-NLP/opus-mt-tc-big-el-en) (`a691085`) |

Changes from the originals: exported to ONNX (encoder + merged decoder with
cache); each side keeps only its own language's vocabulary
(`source_vocab.json` for the encoder, `target_vocab.json` for the decoder;
`</s>`, `<unk>`, `<pad>` are 0, 1, 2 on both sides); weights quantized to
8 bits. Tokenize with `source.spm`, map pieces through `source_vocab.json`,
add `</s>`; decode greedily from `decoder_start_token_id` in `config.json`.

These files are licensed CC-BY-4.0, like the originals. All credit for the
translation models goes to the Helsinki-NLP team (Tiedemann et al.,
*Democratizing neural machine translation with OPUS-MT*, Language Resources
and Evaluation, 2023; Tiedemann & Thottingal, *OPUS-MT — Building open
translation services for the World*, EAMT 2020).
"""

def main() -> None:
    dry = '--dry-run' in sys.argv
    files = []
    stage = Path(tempfile.mkdtemp())
    for direction, src in SOURCES.items():
        for name in FILES:
            f = src / name
            if not f.exists():
                sys.exit(f'missing {f} — make the models first (README.md)')
            dest = stage / FOLDER / direction / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(f, dest)
            data = dest.read_bytes()
            files.append({'path': f'{direction}/{name}', 'bytes': len(data),
                          'sha256': hashlib.sha256(data).hexdigest()})
    (stage / 'README.md').write_text(CARD)
    repo, revision = '', ''
    if not dry:
        from huggingface_hub import HfApi
        api = HfApi()
        user = api.whoami()['name']
        repo = f'{user}/{REPO_NAME}'
        api.create_repo(repo, repo_type='model', private=False, exist_ok=True)
        info = api.upload_folder(repo_id=repo, folder_path=str(stage),
                                 commit_message='OPUS-MT tc-big English-Greek for Lex Hopper')
        revision = info.oid
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps({'repo': repo, 'revision': revision,
                                    'folder': FOLDER, 'files': files},
                                   indent=1) + '\n')
    total = sum(f['bytes'] for f in files)
    where = f'https://huggingface.co/{repo}/tree/{revision}' if repo else '(dry run: not uploaded)'
    print(f'{len(files)} files, {total / 1e6:.0f} MB -> {where}')

if __name__ == '__main__':
    main()
