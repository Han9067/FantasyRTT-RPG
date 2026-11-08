"""Check recognisable landmarks from the user's sketch and exact city correspondence."""
from pathlib import Path
import json, math
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
plan=json.loads((ROOT/'art/world/user_plan_2026_11_08.json').read_text())
layout=json.loads((ROOT/'assets/world/world_layout.json').read_text())
mask=Image.open(ROOT/'docs/world/plan-biomes.png')
assert mask.size==(1824,1368)
# Individually chosen visible landmarks from the reference, not random generator samples.
landmarks={
 'northwest sea':((180,120),4),'northern snow':((1000,100),1),
 'northwest snow bank':((100,20),1),'central forest':((700,330),2),
 'northern mountain belt':((1080,200),3),'inland lake':((1470,360),4),
 'western river':((517,500),4),'northeast sea':((1600,20),4),
 'southern coast':((1750,1350),4),'U-shaped ridge':((1120,717),3),
 'forest inside U ridge':((1170,620),2),'open plain':((850,860),0),
}
for name,(p,kind) in landmarks.items():assert mask.getpixel(p)==kind,(name,mask.getpixel(p),kind)
assert len(plan['cities'])==len(layout['cities'])==42
for i,(src,dst) in enumerate(zip(plan['cities'],layout['cities']),1):
 assert dst['name']==str(i) and src['position']==dst['reference_position']
 expected=[round(src['position'][0]*5120/1824),round(src['position'][1]*3840/1368)]
 assert dst['position']==expected
 assert dst['size']==[128,128]
for chunk in layout['chunks']:
 im=Image.open(ROOT/'assets/world'/chunk['file'])
 assert list(im.size)==chunk['size'] and max(im.size)<=2048
print('PASS: 12 reference landmarks, 42 red-marker positions, numbered cities and native terrain chunks')

# Resource replacement must preserve opaque source pixels at native scale in baked ground.
import hashlib
import numpy as np
resource_dir=ROOT/'art/world/resources'
manifest=json.loads((resource_dir/'manifest.json').read_text())
for entry in manifest['assets']:
 data=(resource_dir/entry['file']).read_bytes()
 assert hashlib.sha256(data).hexdigest()==entry['sha256']
 assert list(Image.open(resource_dir/entry['file']).size)==entry['size']
terrain=Image.new('RGB',tuple(layout['size']))
for chunk in layout['chunks']:
 terrain.paste(Image.open(ROOT/'assets/world'/chunk['file']),tuple(chunk['position']))
city=Image.open(resource_dir/'city.png').convert('RGBA')
city_pixels=np.array(city);opaque=city_pixels[:,:,3]==255
assert opaque.sum()>1000
for entry in layout['cities']:
 x,y=entry['position'];actual=np.array(terrain.crop((x-64,y-64,x+64,y+64)))
 assert np.array_equal(actual[opaque],city_pixels[:,:,:3][opaque]),entry['name']+' does not use the uploaded city pixels'
proofs=json.loads((ROOT/'builds/world-tree-placements.json').read_text())
for name in ['tree1.png','tree2.png']:
 source=np.array(Image.open(resource_dir/name).convert('RGBA'));opaque=source[:,:,3]==255
 found=False
 for entry in reversed(proofs):
  if entry['file']!=name:continue
  x,y=entry['position'];actual=np.array(terrain.crop((x,y,x+48,y+48)))
  if np.array_equal(actual[opaque],source[:,:,:3][opaque]):found=True;break
 assert found,'No unscaled copy of '+name+' in terrain'
assert all(count>0 for count in layout['tree_counts'])
print('PASS: original ZIP resource hashes/sizes, all 42 native city sprites and both native tree sprites in baked terrain')

# Tile borders must agree independently of randomly selected texture variants.
tiles=ROOT/'art/world/tiles'
grid=json.loads((tiles/'tile-grid.json').read_text())
assert grid['tile_size']==32 and grid['size']==[160,120]
assert Image.open(tiles/'ground-tiles.png').size==(256,160)
assert Image.open(tiles/'mountain-tiles.png').size==(256,128)
masks=Image.open(tiles/'corner-masks.png')
assert masks.size==(512,32) and set(np.array(masks).ravel())=={0,255}
cells=grid['cells']
for y,row in enumerate(cells):
 assert len(row)==160
 for x,cell in enumerate(row):
  assert len(cell)==5 and 0<=cell[0]<8 and all(0<=b<16 for b in cell[1:])
  for k,b in enumerate(cell[1:],1):
   if x+1<160:
    right=row[x+1][k]
    assert ((b>>1)&1)==(right&1) and ((b>>3)&1)==((right>>2)&1),'Horizontal terrain corner gap'
    assert np.array_equal(np.array(masks.crop((b*32,0,b*32+32,32)))[:,-1],np.array(masks.crop((right*32,0,right*32+32,32)))[:,0])
   if y+1<120:
    below=cells[y+1][x][k]
    assert ((b>>2)&1)==(below&1) and ((b>>3)&1)==((below>>1)&1),'Vertical terrain corner gap'
for cx,cy,snow,v in grid['mountains']:
 assert 0<=cx<159 and 0<=cy<119 and snow in (0,1) and 0<=v<4
# Final chunks actually contain native atlas pixels, rather than an unrelated visual.
atlas=Image.open(tiles/'ground-tiles.png')
for kind,slot in [(0,None),(1,1),(4,3)]:
 found=False
 for y,row in enumerate(cells):
  for x,cell in enumerate(row):
   if (slot is None and any(cell[1:])) or (slot is not None and cell[slot]!=15):continue
   expected=atlas.crop((cell[0]*32,kind*32,cell[0]*32+32,kind*32+32))
   actual=terrain.crop((x*32,y*32,x*32+32,y*32+32))
   if np.array_equal(np.array(expected),np.array(actual)):found=True;break
  if found:break
 assert found,('Native ground atlas missing in baked map',kind)
print('PASS: 32px tile grid, native atlas pixels, binary corner masks and all shared terrain edges')
