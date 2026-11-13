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


def weapon_grip(family, name, image):
    """Attach to opaque handle pixels at native resolution, including resized art.

    Sword grips sit above the pommel; poles use the lower shaft, leaving a butt
    behind the hand. Explicit anchors preserve the existing starter attachments.
    """
    fixed = {'axe_01': [15,21], 'blunt_01': [16,23], 'sword_01': [15,26],
             'sling_01': [34,31], 'stick_sling_01': [38,41]}
    if name in fixed:
        return fixed[name]
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError(f'Empty weapon: {name}')
    left, top, right, bottom = bounds
    if family in ['spear', 'polearm']:
        y = top + round((bottom - top - 1) * 0.72)
    elif family in ['shield', 'bow', 'crossbow']:
        y = (top + bottom - 1) // 2
    else:
        y = bottom - (4 if family.startswith('sword') else 5)
    xs = [x for x in range(left,right) if image.getpixel((x,y))[3] > 0]
    if not xs:
        raise ValueError(f'No handle pixels for {name} at row {y}')
    return [xs[len(xs)//2], y]


def build(source=SOURCE, dest=DEST):
    catalog = {'schema': 5, 'source_root': 'art/medieval/', 'sheets': {}, 'atlases': [], 'races': {}, 'bodies': [], 'primary_types': [], 'secondary_types': [], 'melee_groups': {}, 'weapon_items': {}}
    pending = []
    def add(group, filename_prefix=None, only_file=None):
        key = group + '.png'
        if key in catalog['sheets']:
            return key
        folder = source / group
        files = [folder/only_file] if only_file else list(folder.glob('*.png'))
        if not files:
            raise ValueError(f'No loose PNGs in {folder}')
        slots = []
        def number(path):
            match = re.fullmatch(re.escape(filename_prefix or folder.name) + r'_(\d+)', path.stem)
            if not match:
                raise ValueError(f'Expected {folder.name}_NN.png: {path}')
            return int(match[1])
        files.sort(key=number)
        ids = [number(path) for path in files]
        if len(ids) != len(set(ids)) or any(i < 1 for i in ids):
            raise ValueError(f'Duplicate or invalid part numbers: {folder}')
        for path in files:
            raw = path.read_bytes()
            with Image.open(path) as image:
                image = image.convert('RGBA')
                if image.width + 2*GUTTER > PAGE_SIZE or image.height + 2*GUTTER > PAGE_SIZE:
                    raise ValueError(f'Part is larger than atlas page: {path}')
                slot = {'name':path.stem, 'source':path.relative_to(source).as_posix(),
                        'sha256':hashlib.sha256(raw).hexdigest(), 'size':list(image.size),
                        'id':number(path)}
                slots.append(slot)
                pending.append((slot, image.copy()))
        catalog['sheets'][key] = {'slots':slots}
        return key

    human = 'sprites/Characters/human'
    catalog['races']['human'] = {
        'heads':[add(f'{human}/head/human_head_skin_{i}') for i in range(1,8)],
        'hair':[add(f'{human}/hair/hairstyle/human_hair_{i}') for i in range(1,9)],
        'beard':[add(f'{human}/hair/facial hair/human_facialhair_{i}') for i in range(1,9)],
        'hand':add(f'{human}/hand/human_hand')}
    catalog['bodies'] = [add(f'sprites/Characters/body/body_{c}') for c in BODY_COLORS]
    # Register every held weapon by filename, not its position in a sheet.
    # Projectile/shot PNGs remain editable sources, not separate equipped weapons.
    for category in ['melee weapons', 'ranged weapons']:
        for folder in sorted((source / 'sprites/weapons' / category).iterdir()):
            if not folder.is_dir() or folder.name.endswith('_shot'):
                continue
            melee = category == 'melee weapons'
            family = folder.name
            if melee:
                hands, family = folder.name.split('_', 1)
                if hands not in ('one', 'two'):
                    raise ValueError(f'Expected one_ or two_ in {folder}')
            prefix = family + '_big' if melee and hands == 'two' and family in ('axe', 'blunt', 'sword') else family
            key = add(folder.relative_to(source).as_posix(), prefix)
            slots = catalog['sheets'][key]['slots']
            if melee:
                catalog['melee_groups'][folder.name] = [slot['name'] for slot in slots]
                if family != 'shield':
                    catalog['primary_types'].append(folder.name)
                if hands == 'one':
                    catalog['secondary_types'].append(folder.name)
            for index, slot in enumerate(slots):
                with Image.open(source / slot['source']) as image:
                    grip = weapon_grip(family, slot['name'], image.convert('RGBA'))
                if slot['name'] in catalog['weapon_items']:
                    raise ValueError(f"Duplicate equipment ID: {slot['name']}")
                catalog['weapon_items'][slot['name']] = {
                    'id': slot['name'], 'family': folder.name, 'sheet': key, 'slot': index,
                    'two_handed': not melee or hands == 'two', 'number': slot['id'],
                    'grip': grip, 'attack': 'thrust_attack' if family == 'spear' else 'chop_attack'}
    catalog['attack_effect'] = add('sprites/VFX/weapon/weaponfx03')
    catalog['thrust_effect'] = add('sprites/VFX/weapon/weaponfx02')
    catalog['infantry_helmet'] = add('sprites/wardrobe/metal/metal', only_file='metal_20.png')
    catalog['attack_references'] = {}
    for attack in ['chop_attack', 'thrust_attack']:
        guide = source / f'Animation Guide/{attack}_sample.gif'
        with Image.open(guide) as gif:
            durations = []
            for frame in range(gif.n_frames):
                gif.seek(frame)
                durations.append(gif.info['duration'])
        if len(durations) != 6:
            raise ValueError(f'Expected six reference poses: {guide}')
        catalog['attack_references'][attack] = {'source':guide.relative_to(source).as_posix(),
            'sha256':hashlib.sha256(guide.read_bytes()).hexdigest(),
            'frames':len(durations), 'durations_ms':durations}

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
    dest.mkdir(parents=True,exist_ok=True)
    for i,page in enumerate(pages):
        path = dest/f'atlas_{i:02d}.png'
        page.save(path)
        catalog['atlases'].append(path.name)
    for path in dest.glob('atlas_*.png'):
        if path.name not in catalog['atlases']:
            path.unlink()
            Path(str(path)+'.import').unlink(missing_ok=True)
    (dest/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n', encoding='utf-8', newline='\n')
    # Verify packing, including gutters/rectangles, against editable source pixels.
    for slot,source_image in pending:
        page=pages[catalog['atlases'].index(slot['atlas'])]
        x,y,w,h=slot['rect']
        if page.crop((x,y,x+w,y+h)).tobytes()!=source_image.tobytes():
            raise AssertionError(f'Atlas changed source pixels: {slot["source"]}')
    print(f'Packed {len(pending)} unchanged parts into {len(pages)} runtime atlas pages.')

if __name__ == '__main__':
    build()
