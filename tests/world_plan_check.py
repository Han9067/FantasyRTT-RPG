"""Verify the game imports the approved Tiled delivery exactly, including city anchors."""
from pathlib import Path
from hashlib import sha256
import json,xml.etree.ElementTree as ET
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/world/tiled'
layout=json.loads((ROOT/'assets/world/world_layout.json').read_text())
manifest=json.loads((SOURCE/'render-manifest.json').read_text())
for name,expected in manifest['inputs'].items():assert sha256((SOURCE/name).read_bytes()).hexdigest()==expected,name
assert sha256((SOURCE/manifest['render_file']).read_bytes()).hexdigest()==manifest['render_sha256']==layout['render_sha256']
assert layout['size']==[5120,3840] and layout['grid_size']==[160,120] and layout['tile_size']==[32,32]
assert 'snow' not in layout['terrain_types']
reference=Image.open(SOURCE/manifest['render_file']).convert('RGB')
actual=Image.new('RGB',tuple(layout['size']))
coverage=np.zeros((3840,5120),dtype=np.uint8)
assert len(layout['chunks'])==6
for chunk in layout['chunks']:
 im=Image.open(ROOT/'assets/world'/chunk['file']).convert('RGB');x,y=chunk['position']
 assert list(im.size)==chunk['size'] and max(im.size)<=2048
 coverage[y:y+im.height,x:x+im.width]+=1;actual.paste(im,(x,y))
assert (coverage==1).all(),'Missing/overlapping terrain chunks'
assert actual.tobytes()==reference.tobytes(),'Game terrain differs from the delivered Tiled map'
mini=Image.open(ROOT/'assets/world/imperial_world.png').convert('RGB')
assert mini.size==(1024,768) and mini.tobytes()==reference.resize(mini.size,Image.Resampling.NEAREST).tobytes()
print('PASS: approved Tiled source hashes, every native world pixel, seamless six chunks and matching minimap')
root=ET.parse(SOURCE/'WorldMap.tmx').getroot()
city_layer=root.find("layer[@name='City']")
data=np.array([int(v) for v in city_layer.find('data').text.replace('\n','').split(',') if v.strip()]).reshape(120,160)
points=root.find("objectgroup[@name='CityPoints']").findall('object')
assert len(points)==len(layout['cities'])==42
assert set(np.unique(data))=={0,454,455,456,470,471,472,486,487,488} and np.count_nonzero(data)==378
sample=np.array(Image.open(SOURCE/'Tiles/ObjectsTiles.png').convert('RGBA').crop((96,288,192,384)))
opaque=sample[:,:,3]==255
for i,city in enumerate(layout['cities'],1):
 assert city['name']==str(i) and city['size']==[96,96]
 p=next(p for p in points if p.get('name')==str(i))
 assert city['position']==[int(float(p.get('x'))),int(float(p.get('y')))]
 x,y=city['position'];tx,ty=city['tile_position']
 assert [x,y]==[tx*32+48,ty*32+48]
 assert np.array_equal(data[ty:ty+3,tx:tx+3],[[454,455,456],[470,471,472],[486,487,488]])
 pixels=np.array(actual.crop((x-48,y-48,x+48,y+48)))
 assert np.array_equal(pixels[opaque],sample[:,:,:3][opaque]),city['name']
print('PASS: all 42 Tiled city centers, original 3x3 sample tiles and exact 96px city pixels')
