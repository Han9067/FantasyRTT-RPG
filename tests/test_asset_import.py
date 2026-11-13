"""Full asset replacement must reject bad input before touching existing files."""
import contextlib
import io
import shutil
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import import_medieval_assets as importer


class AssetImportTest(unittest.TestCase):
    def test_weapons_import_replaces_only_weapons(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, runtime = root/'source', root/'runtime'
            shutil.copytree(ROOT/'art/medieval', source)
            runtime.mkdir()
            weapons = source/'sprites/weapons'
            archive = root/'weapons.zip'
            inputs = {p.relative_to(weapons).as_posix(): p.read_bytes() for p in weapons.rglob('*.png')}
            untouched = {p.relative_to(source).as_posix(): p.read_bytes() for p in source.rglob('*') if p.is_file() and not p.is_relative_to(weapons)}
            (weapons/'removed_weapon.png').write_bytes(b'stale')
            with zipfile.ZipFile(archive,'w') as z:
                for name, data in inputs.items(): z.writestr(name, data)
            with patch.object(importer,'SOURCE',source), patch.object(importer,'DEST',runtime), patch.object(sys,'argv',['import',str(archive),'--weapons']), contextlib.redirect_stdout(io.StringIO()):
                importer.main()
            self.assertEqual({p.relative_to(weapons).as_posix():p.read_bytes() for p in weapons.rglob('*') if p.is_file()}, inputs)
            for name, data in untouched.items(): self.assertEqual((source/name).read_bytes(), data)
            # Invalid scoped imports must preserve both source and runtime.
            catalog = (runtime/'catalog.json').read_bytes()
            with zipfile.ZipFile(archive,'w') as z: z.writestr('../escape.png', b'invalid')
            with patch.object(importer,'SOURCE',source), patch.object(importer,'DEST',runtime), patch.object(sys,'argv',['import',str(archive),'--weapons']):
                with self.assertRaises(ValueError): importer.main()
            self.assertEqual((runtime/'catalog.json').read_bytes(), catalog)
            self.assertFalse((root/'escape.png').exists())

    def test_invalid_zip_preserves_previous_source_and_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source, runtime = root/'source', root/'runtime'
            source.mkdir(); runtime.mkdir()
            (source/'keep.png').write_bytes(b'previous source')
            (runtime/'keep.png').write_bytes(b'previous atlas')
            for entry in ['../escape.png', 'sprites/incomplete.png']:
                archive = root/'bad.zip'
                with zipfile.ZipFile(archive,'w') as z:
                    z.writestr(entry,b'invalid image')
                with patch.object(importer,'SOURCE',source), patch.object(importer,'DEST',runtime), patch.object(sys,'argv',['import',str(archive)]):
                    with self.assertRaises(ValueError):
                        importer.main()
                self.assertEqual((source/'keep.png').read_bytes(), b'previous source')
                self.assertEqual((runtime/'keep.png').read_bytes(), b'previous atlas')
                self.assertFalse((root/'escape.png').exists())

    def test_full_import_removes_stale_files_and_keeps_exact_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);source=root/'source';runtime=root/'runtime'
            (source/'removed_folder').mkdir(parents=True);runtime.mkdir()
            (source/'removed_folder/old.png').write_bytes(b'stale')
            (runtime/'obsolete.png').write_bytes(b'stale')
            archive=root/'new.zip'
            inputs={p.relative_to(ROOT/'art/medieval').as_posix():p for p in (ROOT/'art/medieval').rglob('*') if p.is_file() and p.name!='.gdignore'}
            with zipfile.ZipFile(archive,'w') as z:
                for name,path in inputs.items():z.write(path,name)
            with patch.object(importer,'SOURCE',source), patch.object(importer,'DEST',runtime), patch.object(sys,'argv',['import',str(archive)]), contextlib.redirect_stdout(io.StringIO()):
                importer.main()
            actual={p.relative_to(source).as_posix() for p in source.rglob('*') if p.is_file() and p.name!='.gdignore'}
            self.assertEqual(actual,set(inputs))
            self.assertFalse((source/'removed_folder').exists())
            self.assertFalse((runtime/'obsolete.png').exists())
            self.assertTrue((runtime/'catalog.json').exists())
            for name,path in inputs.items():self.assertEqual((source/name).read_bytes(),path.read_bytes())


if __name__ == '__main__':
    unittest.main()
