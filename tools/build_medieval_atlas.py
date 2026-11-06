#!/usr/bin/env python3
"""Pack editable loose PNGs into deterministic, lossless runtime atlases.
Run after replacing/adding PNGs under art/medieval; no Unity metadata is needed.
"""
import hashlib
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/medieval'
DEST = ROOT / 'assets/medieval'
PAGE_SIZE = 1024
GUTTER = 1
BODY_COLORS = ['black','blue','brown','gold','green','grey','orange','pink','purple','red','silver','yellow']


def build():
    catalog = {'schema': 2, 'source_root': 'art/medieval/', 'sheets': {}, 'atlases': [], 'races': {}, 'bodies': [], 'weapons': []}
    pending = []
    def add(group):
        key = group + '.png'
        if key in catalog['sheets']:
            return key
        folder = SOURCE / group
        files = sorted(folder.glob('*.png'))
        if not files:
            raise ValueError(f'No loose PNGs in {folder}')
        slots = []
        for path in files:
            match = re.search(r'__r(\d+)_c(\d+)$', path.stem)
            if not match:
                raise ValueError(f'Keep the stable __rNN_cNN filename convention: {path}')
            raw = path.read_bytes()
            with Image.open(path) as image:
                image = image.convert('RGBA')
                if image.width + 2*GUTTER > PAGE_SIZE or image.height + 2*GUTTER > PAGE_SIZE:
                    raise ValueError(f'Part is larger than atlas page: {path}')
                slot = {'name':path.stem, 'source':str(path.relative_to(SOURCE)),
                        'sha256':hashlib.sha256(raw).hexdigest(), 'size':list(image.size),
                        'row':int(match[1]), 'column':int(match[2])}
                slots.append(slot)
                pending.append((slot, image.copy()))
        slots.sort(key=lambda s:(s['row'],s['column']))
        catalog['sheets'][key] = {'slots':slots}
        return key

    human = 'sprites/Characters/human'
    catalog['races']['human'] = {
        'heads':[add(f'{human}/head/human_head_skin_{i}') for i in range(1,8)],
        'hair':[add(f'{human}/hair/hairstyle/human_hair_{i}') for i in range(1,9)],
        'beard':[add(f'{human}/hair/facial hair/human_facialhair_{i}') for i in range(1,9)],
        'hand':add(f'{human}/hand/human_hand')}
    catalog['bodies'] = [add(f'sprites/Characters/body/body_{c}') for c in BODY_COLORS]
    for kind, label, row, col, grip in [
        ('axe','한손 도끼',1,1,[15,22]), ('blunt','한손 둔기',1,1,[16,25]), ('sword','한손 검',2,6,[15,28])]:
        key = add(f'sprites/weapons/melee weapons/{kind}')
        # Pin the requested design by stable filename/grid location, even if more weapons are added.
        index = next(i for i,s in enumerate(catalog['sheets'][key]['slots']) if (s['row'],s['column']) == (row,col))
        catalog['weapons'].append({'id':kind,'label':label,'sheet':key,'slot':index,'grip':grip})
    catalog['attack_effect'] = add('sprites/VFX/weapon/weaponfx03')

    pages = [Image.new('RGBA', (PAGE_SIZE,PAGE_SIZE))]
    x = y = GUTTER
    row_height = 0
    for slot, image in pending:
        w,h = image.size
        if x+w+GUTTER > PAGE_SIZE:
            x = GUTTER
            y += row_height + 2*GUTTER
            row_height = 0
        if y+h+GUTTER > PAGE_SIZE:
            pages.append(Image.new('RGBA', (PAGE_SIZE,PAGE_SIZE)))
            x = y = GUTTER
            row_height = 0
        name = f'atlas_{len(pages)-1:02d}.png'
        # No alpha mask: preserve every RGBA byte, including transparent RGB.
        pages[-1].paste(image, (x,y))
        slot.update(atlas=name, rect=[x,y,w,h])
        x += w+2*GUTTER
        row_height = max(row_height,h)
    DEST.mkdir(parents=True,exist_ok=True)
    for i,page in enumerate(pages):
        path = DEST/f'atlas_{i:02d}.png'
        page.save(path)
        catalog['atlases'].append(path.name)
    for path in DEST.glob('atlas_*.png'):
        if path.name not in catalog['atlases']:
            path.unlink()
            Path(str(path)+'.import').unlink(missing_ok=True)
    (DEST/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
    # Verify packing, including gutters/rectangles, against editable source pixels.
    for slot,source_image in pending:
        page=pages[catalog['atlases'].index(slot['atlas'])]
        x,y,w,h=slot['rect']
        if page.crop((x,y,x+w,y+h)).tobytes()!=source_image.tobytes():
            raise AssertionError(f'Atlas changed source pixels: {slot["source"]}')
    print(f'Packed {len(pending)} unchanged parts into {len(pages)} runtime atlas pages.')

if __name__ == '__main__':
    build()
