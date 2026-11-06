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
    with tempfile.TemporaryDirectory(prefix='medieval-import-') as temp:
        staging = Path(temp)/'source'
        generated = Path(temp)/'runtime'
        staging.mkdir()
        names = set()
        with zipfile.ZipFile(sys.argv[1]) as archive:
            for info in archive.infolist():
                if info.is_dir():
                    continue
                path = PurePosixPath(info.filename)
                if (path.is_absolute() or '..' in path.parts or '\\' in info.filename
                        or stat.S_ISLNK(info.external_attr >> 16)
                        or path.suffix.lower() not in {'.png', '.gif', '.rtf'}
                        or info.filename in names):
                    raise ValueError(f'Invalid asset entry: {info.filename}')
                target = staging/str(path)
                target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes(archive.read(info))
                names.add(info.filename)
        (staging/'.gdignore').write_text('')
        # Resolve all renamed active parts, parse the guide and verify atlas pixels
        # before touching the existing project source or runtime output.
        build(staging, generated)
        for directory, prepared in [(SOURCE,staging),(DEST,generated)]:
            if directory.exists():
                shutil.rmtree(directory)
            directory.parent.mkdir(parents=True,exist_ok=True)
            shutil.move(str(prepared), str(directory))
        actual = {str(p.relative_to(SOURCE)) for p in SOURCE.rglob('*') if p.is_file() and p.name != '.gdignore'}
        if actual != names:
            raise AssertionError('Imported tree differs from ZIP file list')
        with zipfile.ZipFile(sys.argv[1]) as archive:
            if any((SOURCE/name).read_bytes() != archive.read(name) for name in names):
                raise AssertionError('Imported bytes differ from ZIP')
        print(f'Replaced source with exactly {len(names)} ZIP files; no previous files retained.')

if __name__ == '__main__':
    main()
