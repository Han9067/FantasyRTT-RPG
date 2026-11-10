"""Derive passability from actual Tiled tilesets, without modifying visual layers."""
import xml.etree.ElementTree as ET

# GroundTiles local (zero-based) water/shore atlas cells. Green terrain variants
# beside them are deliberately excluded. RiverTiles and LakeTiles are all water.
GROUND_WATER = set(range(185,189)) | {194,195} | set(range(199,203)) | {208,209} | set(range(213,259))

def navigation_data(tmx, source):
    cols, rows = int(tmx.get('width')), int(tmx.get('height'))
    tilesets = []
    for ref in tmx.findall('tileset'):
        ts = ET.parse(source / ref.get('source')).getroot()
        tilesets.append((int(ref.get('firstgid')), int(ts.get('tilecount')), ts.get('name')))
    mountain, water, road = set(), {}, {}
    for order, layer in enumerate(tmx.findall('layer')):
        if layer.get('visible', '1') == '0': continue
        assert int(layer.get('width')) == cols and int(layer.get('height')) == rows
        assert not float(layer.get('offsetx','0')) and not float(layer.get('offsety','0'))
        data = layer.find('data'); assert data.get('encoding') == 'csv'
        cells = [int(v) & 0x0fffffff for v in data.text.replace('\n','').split(',') if v.strip()]
        assert len(cells) == cols*rows
        for index, gid in enumerate(cells):
            if not gid: continue
            first, count, name = next(ts for ts in tilesets if ts[0] <= gid < ts[0]+ts[1])
            cell = (index % cols, index // cols)
            if name in ('MountainTiles', 'MountainDarkTiles'): mountain.add(cell)
            if name in ('RiverTiles','LakeTiles') or (name == 'GroundTiles' and gid-first in GROUND_WATER): water[cell] = order
            if name in ('RoadTiles','RoadDarkTiles'): road[cell] = order
    bridges = {cell for cell in water if road.get(cell,-1) > water[cell] and cell not in mountain}
    blocked = mountain | (set(water) - bridges)
    ordered = lambda cells: [list(c) for c in sorted(cells,key=lambda c:(c[1],c[0]))]
    return {'cell_size':[int(tmx.get('tilewidth')),int(tmx.get('tileheight'))],
            'grid_size':[cols,rows], 'blocked':ordered(blocked), 'bridges':ordered(bridges),
            'mountains':ordered(mountain), 'water':ordered(water), 'roads':ordered(road)}
