#!/usr/bin/env python3
"""Upload the app's databases to Hugging Face and point the app at them.
Run after scripts/build_databases.py, signed in with a Write token
(`.models/venv/bin/hf auth login`):

    .models/venv/bin/python scripts/upload_databases.py [--dry-run]

Gzips assets/lexicon.db and assets/texts.db into the public dataset
repository <you>/lex-hopper-data as databases/<name>_<fingerprint>.db.gz
(earlier versions stay there for older apps), with the licences and credits
of data/licences/, then rewrites assets/databases.json: the fingerprints,
the repository, the commit to download from, and each file's sizes and
SHA-256. The app downloads them on first launch (lib/database_download.dart).
"""
import gzip, hashlib, json, shutil, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO_NAME = 'lex-hopper-data'
VERSIONS = ROOT / 'assets/databases.json'
LICENCES = ROOT / 'data/licences'

CARD = """---
license: other
license_name: mixed-see-licences
language: [en, el]
pretty_name: Lex Hopper dictionary data
---

# Lex Hopper dictionary data

The English–Greek dictionary databases the Lex Hopper app downloads on its
first launch (SQLite, gzipped), built from the CSV files of the app's
repository by `scripts/build_databases.py`. `databases/` holds every
version, named `<database>_<fingerprint>.db.gz`.

## Sources, licences and credits

The data was first seeded from the sources below; their licences still
apply to what came from them. Their licence texts are in `licences/`.

"""

def main() -> None:
    dry = '--dry-run' in sys.argv
    fps = json.loads(VERSIONS.read_text())
    stage = Path(tempfile.mkdtemp())
    (stage / 'databases').mkdir()
    files = {}
    for name in ('lexicon', 'texts'):
        src = ROOT / 'assets' / f'{name}.db'
        if not src.exists():
            sys.exit(f'missing {src} — run scripts/build_databases.py first')
        out = stage / 'databases' / f"{name}_{fps[name]}.db.gz"
        with open(src, 'rb') as f, gzip.GzipFile(out, 'wb', compresslevel=9, mtime=0) as g:
            shutil.copyfileobj(f, g, 1 << 20)
        data = out.read_bytes()
        files[name] = {'path': f'databases/{out.name}', 'gz_bytes': len(data),
                       'sha256': hashlib.sha256(data).hexdigest(),
                       'bytes': src.stat().st_size}
    readme = (LICENCES / 'README.md').read_text(encoding='utf-8')
    table = readme[readme.index('| Source'):] if '| Source' in readme else readme
    (stage / 'README.md').write_text(CARD + table, encoding='utf-8')
    shutil.copytree(LICENCES, stage / 'licences')
    repo, revision = '', ''
    if not dry:
        from huggingface_hub import HfApi
        api = HfApi()
        repo = f"{api.whoami()['name']}/{REPO_NAME}"
        api.create_repo(repo, repo_type='dataset', private=False, exist_ok=True)
        info = api.upload_folder(repo_id=repo, repo_type='dataset',
                                 folder_path=str(stage),
                                 commit_message=f"Databases lexicon {fps['lexicon']}, texts {fps['texts']}")
        revision = info.oid
    VERSIONS.write_text(json.dumps({
        'lexicon': fps['lexicon'], 'texts': fps['texts'],
        'repo': repo, 'repo_type': 'dataset', 'revision': revision,
        'files': files,
    }, indent=2) + '\n', encoding='utf-8')
    total = sum(f['gz_bytes'] for f in files.values())
    where = f'https://huggingface.co/datasets/{repo}/tree/{revision}' if repo else '(dry run: not uploaded)'
    print(f'2 databases, {total / 1e6:.0f} MB to download -> {where}')

if __name__ == '__main__':
    main()
