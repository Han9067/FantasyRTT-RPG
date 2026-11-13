#!/usr/bin/env python3
"""Replace the complete source tree with a validated ZIP; never merge stale files.
For a single image edit, replace its PNG directly and run build_medieval_atlas.py.
"""
import shutil
import stat
import sys
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
from build_medieval_atlas import build, SOURCE, DEST


def main():
    weapons_only = '--weapons' in sys.argv[2:]
    with tempfile.TemporaryDirectory(prefix='medieval-import-', dir=SOURCE.parent) as temp:
        staging = Path(temp)/'source'
        generated = Path(temp)/'runtime'
        if weapons_only:
            shutil.copytree(SOURCE, staging)
            shutil.rmtree(staging/'sprites/weapons')
            imported = staging/'sprites/weapons'
            imported.mkdir()
        else:
            staging.mkdir()
            imported = staging
        names = set()
        with zipfile.ZipFile(sys.argv[1]) as archive:
            for info in archive.infolist():
                if info.is_dir():
                    continue
                path = PurePosixPath(info.filename)
                if (path.is_absolute() or '..' in path.parts or '\\' in info.filename or ':' in info.filename
                        or stat.S_ISLNK(info.external_attr >> 16)
                        or path.suffix.lower() not in {'.png', '.gif', '.rtf'}
                        or info.filename in names):
                    raise ValueError(f'Invalid asset entry: {info.filename}')
                if weapons_only and (path.parts[0] not in {'melee weapons', 'ranged weapons', 'projectiles & bullets'} or path.suffix.lower() != '.png'):
                    raise ValueError(f'Invalid weapon entry: {info.filename}')
                target = imported/str(path)
                target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes(archive.read(info))
                names.add(info.filename)
        (staging/'.gdignore').write_text('')
        # Resolve all renamed active parts, parse the guide and verify atlas pixels
        # before touching the existing project source or runtime output.
        build(staging, generated)
        actual = {p.relative_to(imported).as_posix() for p in imported.rglob('*') if p.is_file() and p.name != '.gdignore'}
        if actual != names:
            raise AssertionError('Imported tree differs from ZIP file list')
        with zipfile.ZipFile(sys.argv[1]) as archive:
            if any((imported/name).read_bytes() != archive.read(name) for name in names):
                raise AssertionError('Imported bytes differ from ZIP')
        for page in generated.glob('*.png'):
            metadata = DEST/(page.name+'.import')
            if metadata.is_file():
                shutil.copy2(metadata, generated/metadata.name)
        target = SOURCE/'sprites/weapons' if weapons_only else SOURCE
        backups, installed = [], []
        try:
            for directory, prepared in [(target, imported), (DEST, generated)]:
                directory.parent.mkdir(parents=True, exist_ok=True)
                if directory.exists():
                    backup = Path(temp)/f'previous-{len(backups)}'
                    directory.rename(backup)
                    backups.append((directory, backup))
                prepared.rename(directory)
                installed.append(directory)
        except OSError:
            for directory in reversed(installed):
                shutil.rmtree(directory)
            for directory, backup in reversed(backups):
                backup.rename(directory)
            raise
        print(f'Replaced {"weapons" if weapons_only else "source"} with exactly {len(names)} ZIP files; no previous files retained in that subtree.')

if __name__ == '__main__':
    main()
