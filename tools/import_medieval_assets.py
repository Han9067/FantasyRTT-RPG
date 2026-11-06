#!/usr/bin/env python3
"""Import the user's loose-PNG ZIP, retaining exact filenames/bytes, then rebuild.
For later edits, replace just the PNG in art/medieval and run build_medieval_atlas.py.
"""
import sys
import zipfile
from pathlib import Path
from build_medieval_atlas import build, SOURCE


def main():
    SOURCE.mkdir(parents=True,exist_ok=True)
    count = 0
    with zipfile.ZipFile(sys.argv[1]) as archive:
        for name in archive.namelist():
            if name.endswith('/'):
                continue
            target = SOURCE/name
            if not target.resolve().is_relative_to(SOURCE.resolve()) or target.suffix.lower() != '.png':
                raise ValueError(f'Expected an asset PNG within archive root: {name}')
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(archive.read(name))
            count += 1
    (SOURCE/'.gdignore').write_text('')
    print(f'Imported {count} editable PNGs without changing their bytes.')
    build()

if __name__ == '__main__':
    main()
