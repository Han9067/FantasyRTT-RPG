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
# Category order is the creator order; variants within each category use English color order.
OUTFITS = {
    'tunic_beige': '베이지 튜닉', 'tunic_black': '검정 튜닉', 'tunic_blue': '파란 튜닉',
    'tunic_green': '초록 튜닉', 'tunic_red': '빨간 튜닉', 'tunic_white': '흰색 튜닉',
    'leather vest_black': '검정 가죽 조끼', 'leather vest_brown': '갈색 가죽 조끼',
    'gambeson_blue': '파란 갬비슨', 'gambeson_green': '초록 갬비슨',
    'gambeson_red': '빨간 갬비슨', 'gambeson_white': '흰색 갬비슨', 'chain mail': '체인 메일',
}


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


def load_weapon_offsets(path=ROOT / 'data/weapon_offsets.json'):
    """Use a reviewed Sheets snapshot; positive Y means upward in the game."""
    rows = json.loads(path.read_text(encoding='utf-8'))['rows']
    if rows[0] != ['이름(한글)', '종류', 'Y']:
        raise ValueError('Unexpected weapon sheet headers')
    families = {'한손검':'one_sword', '한손도끼':'one_axe', '한손둔기':'one_blunt',
                '양손검':'two_sword', '양손도끼':'two_axe', '양손둔기':'two_blunt',
                '활':'bow', '장병기':'two_polearm', '창':'two_spear', '양손장병기':'two_polearm', '양손창':'two_spear'}
    offsets = {}
    for row in rows[1:]:
        if not row or not any(str(v).strip() for v in row):
            continue
        if 2 <= len(row) <= 3 and row[1] == '양손도끼' and (len(row) == 2 or row[2] is None or row[2] == ''):
            continue  # Planned axes have no reviewed Y yet; zero is a valid offset.
        if len(row) != 3:
            raise ValueError(f'Incomplete weapon row: {row}')
        name, kind, y = row
        kind = str(kind).replace(' ', '')
        match = re.fullmatch(re.escape(kind) + r'([1-9][0-9]*)', str(name).replace(' ', ''))
        if kind not in families or not match or type(y) not in (int, float) or not float(y).is_integer():
            raise ValueError(f'Invalid weapon offset: {row}')
        key = f'{families[kind]}/{int(match[1])}'
        if key in offsets:
            raise ValueError(f'Duplicate weapon offset: {key}')
        offsets[key] = int(y)
    return offsets


def build(source=SOURCE, dest=DEST):
    catalog = {'schema': 6, 'source_root': 'art/medieval/', 'sheets': {}, 'atlases': [], 'races': {}, 'bodies': [], 'primary_types': [], 'secondary_types': [], 'melee_groups': {}, 'ranged_groups': {}, 'weapon_items': {}}
    offsets = load_weapon_offsets()
    pending = []
    def add(group, filename_prefix=None, only_file=None, only_files=None, numeric=False, series=None):
        key = (f'{group}/{series}' if series else group) + '.png'
        if key in catalog['sheets']:
            return key
        folder = source / group
        files = [folder/name for name in only_files] if only_files else ([folder/only_file] if only_file else list(folder.glob('*.png')))
        if not files:
            raise ValueError(f'No loose PNGs in {folder}')
        slots = []
        def number(path):
            prefix = series if series else ('' if numeric else (filename_prefix or folder.name) + '_')
            match = re.fullmatch(re.escape(prefix) + r'(\d+)', path.stem)
            if not match:
                raise ValueError(f'Invalid numbered PNG: {path}')
            return int(match[1])
        files.sort(key=number)
        ids = [number(path) for path in files]
        if len(ids) != len(set(ids)) or any(i < 1 for i in ids):
            raise ValueError(f'Duplicate or invalid part numbers: {folder}')
        if numeric and only_files is None and ids != list(range(1, len(ids) + 1)):
            raise ValueError(f'Melee numbering must be sequential from 1: {folder}')
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

    characters = 'sprites/Characters'
    hair_colors = sorted(p.name for p in (source / characters / 'hair').iterdir() if p.is_dir())
    catalog['races']['human'] = {
        'heads':[add(f'{characters}/head', only_files=[f'{series}{i}.png' for i in range(1,8)], series=series)
                 for series in ['m','f']],
        'eye':add(f'{characters}/eye', numeric=True),
        'hair':[[add(f'{characters}/hair/{color}', only_files=[f'{series}{i}.png' for i in range(1, count + 1)], series=series)
                 for color in hair_colors] for series, count in [('m', 7), ('f', 3)]],
        'hand':add(f'{characters}/hand', numeric=True)}
    catalog['body_ids'] = list(OUTFITS)
    catalog['body_labels'] = list(OUTFITS.values())
    for outfit in OUTFITS:
        catalog['bodies'].append(add(f'sprites/Characters/body/{outfit}',
                                     only_files=[f'{i}.png' for i in range(1, 9)], numeric=True))
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
            files = None
            if folder.name == 'two_axe':
                files = [p.name for p in folder.glob('*.png') if f'two_axe/{p.stem}' in offsets]
                if not files:
                    continue
            key = add(folder.relative_to(source).as_posix(), prefix, only_files=files, numeric=melee or family == 'bow')
            slots = catalog['sheets'][key]['slots']
            if melee:
                catalog['melee_groups'][folder.name] = [f"{folder.name}/{slot['id']}" for slot in slots]
                if family != 'shield':
                    catalog['primary_types'].append(folder.name)
                if hands == 'one':
                    catalog['secondary_types'].append(folder.name)
            elif family in ('bow', 'crossbow'):
                # Append to preserve the primary type indices in saved appearances.
                catalog['primary_types'].append(family)
                catalog['ranged_groups'][family] = []
            for index, slot in enumerate(slots):
                with Image.open(source / slot['source']) as image:
                    grip = weapon_grip(family, slot['name'], image.convert('RGBA'))
                equipment_id = f"{folder.name}/{slot['id']}" if melee or family == 'bow' else slot['name']
                if family in catalog['ranged_groups']:
                    catalog['ranged_groups'][family].append(equipment_id)
                if equipment_id in catalog['weapon_items']:
                    raise ValueError(f"Duplicate equipment ID: {slot['name']}")
                catalog['weapon_items'][equipment_id] = {
                    'id': equipment_id, 'family': folder.name, 'sheet': key, 'slot': index,
                    'number': slot['id'], 'price': 100,
                    'grip': grip, 'attack': 'bow_shot' if family == 'bow' else ('thrust_attack' if family == 'spear' else 'chop_attack')}
    for equipment_id, y_up in offsets.items():
        if equipment_id not in catalog['weapon_items']:
            if equipment_id.startswith('two_axe/'):
                continue  # The art may arrive after its spreadsheet row.
            raise ValueError(f'Sheet weapon missing from source: {equipment_id}')
        catalog['weapon_items'][equipment_id]['y_up'] = y_up
    weapon_data = json.loads((ROOT / 'data/weapon_ids.json').read_text(encoding='utf-8'))
    sheet_items = weapon_data['items']
    ids = [row['item_id'] for row in sheet_items.values()]
    if any(type(i) is not int or i <= 0 for i in ids) or len(set(ids)) != len(ids):
        raise ValueError('Weapon sheet IDs must be unique positive integers')
    for key, row in sheet_items.items():
        if type(row['equip_type']) is not int or row['equip_type'] not in range(4) or type(row['is_unique']) is not bool:
            raise ValueError(f'Invalid sheet equipment data: {key}')
    for key, item in catalog['weapon_items'].items():
        if key in sheet_items:
            item.update(sheet_items[key])
        else:
            # Shields and crossbows have no sheet rows yet. Preserve their old grips.
            item['equip_type'] = 1 if item['family'] == 'crossbow' else 0
            item['is_unique'] = False
        item['two_handed'] = item['equip_type'] != 0
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

    # Each numbered bow has twelve consecutive native shooting frames.
    shot_count = 12 * len(catalog['ranged_groups']['bow'])
    catalog['bow_shot'] = add('sprites/weapons/ranged weapons/bow_shot',
                              only_files=[f'bow_shot_{i:02d}.png' for i in range(1, shot_count + 1)])
    catalog['arrow'] = add('sprites/weapons/projectiles/arrow', only_file='arrow_01.png')
    catalog['attack_references']['bow_shot'] = {'frames':12, 'durations_ms':[100]*12,
        'source':'sprites/weapons/ranged weapons/bow_shot', 'release_frame':7}

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
