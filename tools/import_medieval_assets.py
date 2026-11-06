#!/usr/bin/env python3
"""Import unchanged character PNGs and Unity sprite rectangles from the purchased ZIP.
Usage: python tools/import_medieval_assets.py /path/to/MedievalFantasyCharacters.zip
Requires PyYAML and Pillow for reading metadata/image dimensions, not redrawing.
"""
import hashlib, io, json, sys, zipfile
from pathlib import Path
import yaml
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/medieval'
RACES = ['human', 'elf', 'goblin', 'orc']
COLORS = ['black', 'blue', 'green', 'orange', 'pink', 'purple', 'red', 'yellow']

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    catalog = {'sheets': {}, 'races': {}, 'bodies': [], 'headgear': []}
    with zipfile.ZipFile(sys.argv[1]) as z:
        def add(path):
            if path in catalog['sheets']:
                return path
            raw = z.read(path)
            im = Image.open(io.BytesIO(raw))
            meta = yaml.safe_load(z.read(path + '.meta'))['TextureImporter']
            slots = []
            for s in meta['spriteSheet']['sprites']:
                q = s['rect']
                x, y, w, h = [int(q[k]) for k in ('x','y','width','height')]
                slots.append({'name': s['name'], 'rect': [x, im.height-y-h, w, h]})
            dst = DEST / path
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(raw)
            catalog['sheets'][path] = {'size': list(im.size), 'sha256': hashlib.sha256(raw).hexdigest(), 'slots': slots}
            return path
        for race in RACES:
            base = f'sprites/Characters/{race}'
            catalog['races'][race] = {
                'heads': [add(p) for p in sorted(z.namelist()) if p.startswith(base+'/head/') and p.endswith('.png')],
                'hair': [add(f'{base}/hair/hairstyle/{race}_hair_{i}.png') for i in range(1,9)],
                'beard': [add(f'{base}/hair/facial hair/{race}_facialhair_{i}.png') for i in range(1,9)],
                'hand': add(f'{base}/hand/{race}_hand.png')}
        for color in ['black','blue','brown','gold','green','grey','orange','pink','purple','red','silver','yellow']:
            catalog['bodies'].append(add(f'sprites/Characters/body/body_{color}.png'))
        catalog['gloves'] = add('sprites/Characters/hand gloved/gloved.png')
        for key, label, paths in [
            ('none','없음', []),
            ('cloth','천 모자',[f'cloth/hat_{c}.png' for c in COLORS]),
            ('straw','밀짚모자',['cloth/hat_straw.png']),
            ('leather','가죽 모자',['leather/leather01.png']),
            ('leather_tall','장식 가죽 모자',['leather/leather02.png']),
            ('metal','금속 투구',['metal/metal.png']),
            ('metal_tall','장식 금속 투구',[f'metal/metal_{c}.png' for c in COLORS])]:
            catalog['headgear'].append({'id':key,'label':label,'sheets':[add('sprites/wardrobe/'+p) for p in paths]})
        # Fixed starter weapons selected by the user. Last sword means the last
        # non-empty registered sprite, not the final empty cell in the PNG grid.
        catalog['weapons'] = []
        for kind, label, grip in [('axe', '한손 도끼', [15, 22]), ('blunt', '한손 둔기', [16, 25]), ('sword', '한손 검', [15, 28])]:
            path = add(f'sprites/weapons/melee weapons/{kind}.png')
            index = len(catalog['sheets'][path]['slots']) - 1 if kind == 'sword' else 0
            catalog['weapons'].append({'id': kind, 'label': label, 'sheet': path, 'slot': index, 'grip': grip})
    (DEST/'catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n')
    print(f'Imported {len(catalog["sheets"])} unchanged PNG sheets.')

if __name__ == '__main__':
    main()
