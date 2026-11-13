"""Bake the 8px water and 16px mountain masks on a shared grid.

Water colours are from the supplied palettes (transparent pixels are ignored).
Rock silhouettes exclude green foothill decoration. Roads open only their dirt
surface; bridge objects replace that opening with the actual opaque deck.
"""
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image

CELL_SIZE = 4
WATER_SIZE = 8
MOUNTAIN_SIZE = 16
WATER_COLOURS = {(69,100,114), (66,93,114), (57,83,106)}
ROAD_COLOURS = {(147,132,89), (145,125,83), (139,119,85), (126,104,67), (128,107,70)}
# ObjectsTiles local 10: horizontal stone bridge. Its translucent shadow and
# transparent margins are not walking surface. Tile flags rotate/flip this too.
BRIDGE_IDS = {10}

def colour_mask(pixels, colours):
    result = np.zeros(pixels.shape[:2], dtype=bool)
    for colour in colours:
        result |= np.all(pixels[:,:,:3] == colour, axis=2)
    return result & (pixels[:,:,3] >= 128)

def transform(mask, flags):
    if flags & 0x20000000: mask = mask.T
    if flags & 0x80000000: mask = mask[:,::-1]
    if flags & 0x40000000: mask = mask[::-1,:]
    return mask

def terrain_masks(tmx, source):
    cols, rows = int(tmx.get('width')), int(tmx.get('height'))
    tw, th = int(tmx.get('tilewidth')), int(tmx.get('tileheight'))
    tilesets = []
    for ref in tmx.findall('tileset'):
        ts = ET.parse(source / ref.get('source')).getroot()
        pixels = np.array(Image.open(source / ts.find('image').get('source')).convert('RGBA'))
        tilesets.append((int(ref.get('firstgid')), int(ts.get('tilecount')), ts, pixels))
    water = np.zeros((rows*th,cols*tw), dtype=bool)
    mountain = np.zeros_like(water)
    opening = np.zeros_like(water)
    bridge_surface = np.zeros_like(water)
    bridges = []
    cache = {}
    for layer in tmx.findall('layer'):
        if layer.get('visible','1') == '0': continue
        assert int(layer.get('width')) == cols and int(layer.get('height')) == rows
        assert not float(layer.get('offsetx','0')) and not float(layer.get('offsety','0'))
        data = layer.find('data'); assert data.get('encoding') == 'csv'
        cells = [int(v) for v in data.text.replace('\n','').split(',') if v.strip()]
        assert len(cells) == cols*rows
        for index, raw in enumerate(cells):
            if not raw: continue
            gid, flags = raw & 0x0fffffff, raw & 0xf0000000
            if raw not in cache:
                first, count, ts, pixels = next(ts for ts in tilesets if ts[0] <= gid < ts[0]+ts[1])
                name, local, tc = ts.get('name'), gid-first, int(ts.get('columns'))
                x,y = local%tc*tw, local//tc*th
                tile = pixels[y:y+th,x:x+tw]
                opaque = tile[:,:,3] >= 128
                if name in ('GroundTiles','RiverTiles','LakeTiles'):
                    kind, mask = 'water', colour_mask(tile,WATER_COLOURS)
                elif name in ('MountainTiles','MountainDarkTiles'):
                    # Keep grey/brown rock, omit grassy skirt pixels around its foot.
                    green = (tile[:,:,1].astype(int) > tile[:,:,2]*1.3) & (tile[:,:,0].astype(int) > tile[:,:,2]*1.2) & (tile[:,:,2]<80)
                    kind, mask = 'mountain', opaque & ~green
                elif name in ('RoadTiles','RoadDarkTiles'):
                    kind, mask = 'road', colour_mask(tile,ROAD_COLOURS)
                elif name == 'ObjectsTiles' and local in BRIDGE_IDS:
                    kind, mask = 'bridge', opaque
                else: continue
                cache[raw] = kind, transform(mask,flags), transform(opaque,flags), name
            kind, mask, opaque, name = cache[raw]
            x,y = index%cols*tw, index//cols*th
            region = np.s_[y:y+th,x:x+tw]
            if kind == 'mountain': mountain[region] |= mask
            elif kind == 'water':
                if name == 'GroundTiles': water[region][opaque] = False
                water[region] |= mask
                opening[region][mask] = False  # Later water covers earlier roads.
            elif kind == 'road': opening[region] |= mask
            elif kind == 'bridge':
                # A bridge replaces the underlying road's entire tile opening,
                # so neither road fringe nor bridge shadow can open nearby water.
                opening[region] = mask
                bridge_surface[region] = mask
                bridges.append([index%cols,index//cols])
    blocked = mountain | (water & ~opening)
    return blocked, mountain, water, bridges, bridge_surface

def navigation_data(tmx, source):
    pixels, mountain, water, bridges, bridge_surface = terrain_masks(tmx,source)
    h,w = pixels.shape
    assert w % CELL_SIZE == h % CELL_SIZE == 0
    def cells(mask, size):
        return mask.reshape(h//size,size,w//size,size).any(axis=(1,3))

    def expand(mask, size):
        factor = size // CELL_SIZE
        return mask.repeat(factor,axis=0).repeat(factor,axis=1)

    blocked = expand(cells(pixels & ~mountain, WATER_SIZE), WATER_SIZE)
    # The ten-pixel-wide deck straddles the 8px grid. Retain its original
    # conservative 4px silhouette inside bridge tiles so only dry cells open.
    deck = ~cells(~bridge_surface, CELL_SIZE) & ~cells(pixels, CELL_SIZE)
    blocked[deck] = False
    blocked |= expand(cells(mountain, MOUNTAIN_SIZE), MOUNTAIN_SIZE)
    ys,xs = np.nonzero(blocked)
    return {'cell_size':[CELL_SIZE,CELL_SIZE], 'grid_size':[w//CELL_SIZE,h//CELL_SIZE],
            'blocked':np.column_stack((xs,ys)).tolist(), 'bridge_tiles':bridges,
            'source_pixel_size':[w,h], 'water_cell_size':WATER_SIZE, 'mountain_cell_size':MOUNTAIN_SIZE}
