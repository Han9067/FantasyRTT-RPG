"""Verify exact uploaded visuals, native chunks, minimap and hidden game metadata."""
from pathlib import Path
from hashlib import sha256
import copy,json,math,xml.etree.ElementTree as ET
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/world/tiled'
layout=json.loads((ROOT/'assets/world/world_layout.json').read_text())
manifest=json.loads((SOURCE/'render-manifest.json').read_text())
upload=json.loads((SOURCE/'upload-manifest.json').read_text())
for name,expected in upload['files'].items():
 path=SOURCE/(upload['original_tmx'] if name=='WorldMap.tmx' else name)
 assert sha256(path.read_bytes()).hexdigest()==expected,('Upload modified',name)
original=ET.parse(SOURCE/upload['original_tmx']).getroot()
root=ET.parse(SOURCE/'WorldMap.tmx').getroot()
attrs=lambda node:{k:v for k,v in node.attrib.items() if k not in ['nextlayerid','nextobjectid']}
assert attrs(root)==attrs(original)
def visual_xml(child):
 node=copy.deepcopy(child);node.tail=None
 return ET.tostring(node)
visible_source=[visual_xml(child) for child in original]
visible_current=[visual_xml(child) for child in root if child.get('name')!='GameObjects']
assert visible_current==visible_source,'Uploaded tile layers/properties/tilesets changed'
objects=root.find("objectgroup[@name='GameObjects']")
assert objects is not None and objects.get('visible')=='0'
for name,expected in manifest['inputs'].items():assert sha256((SOURCE/name).read_bytes()).hexdigest()==expected,name
assert sha256((SOURCE/manifest['render_file']).read_bytes()).hexdigest()==manifest['render_sha256']==layout['render_sha256']
assert sha256((SOURCE/upload['original_render']).read_bytes()).hexdigest()==upload['original_render_sha256']
assert layout['size']==[2560,1280] and layout['grid_size']==[80,40] and layout['tile_size']==[32,32]
w,h=layout['size'];cols,rows=layout['grid_size'];tw,th=layout['tile_size']
reference=Image.open(SOURCE/manifest['render_file']).convert('RGB')
original_render=Image.open(SOURCE/upload['original_render']).convert('RGB')
assert reference.size==original_render.size==(w,h)
assert reference.tobytes()==original_render.tobytes(),'Added metadata changed map pixels'
actual=Image.new('RGB',(w,h));coverage=np.zeros((h,w),dtype=np.uint8)
assert len(layout['chunks'])==math.ceil(w/2048)*math.ceil(h/2048)==2
for chunk in layout['chunks']:
 im=Image.open(ROOT/'assets/world'/chunk['file']).convert('RGB');x,y=chunk['position']
 assert list(im.size)==chunk['size'] and max(im.size)<=2048
 coverage[y:y+im.height,x:x+im.width]+=1;actual.paste(im,(x,y))
assert (coverage==1).all(),'Missing/overlapping terrain chunks'
assert actual.tobytes()==reference.tobytes(),'Game terrain differs from the uploaded Tiled map'
assert {p.name for p in (ROOT/'assets/world/chunks').glob('*.png')}=={Path(c['file']).name for c in layout['chunks']},'Stale terrain chunks'
mini=Image.open(ROOT/'assets/world/imperial_world.png').convert('RGB')
assert mini.size==(1024,512) and list(mini.size)==layout['minimap_size']
assert mini.tobytes()==reference.resize(mini.size,Image.Resampling.NEAREST).tobytes()
print('PASS: uploaded visuals/assets unchanged, native 2560x1280 pixels, two seamless chunks, 2:1 minimap')
city_layer=root.find("layer[@name='City']")
data=np.array([int(v) for v in city_layer.find('data').text.replace('\n','').split(',') if v.strip()]).reshape(rows,cols)
points=[o for o in objects.findall('object') if o.get('type')=='City']
assert len(points)==len(layout['cities'])==4
assert set(np.unique(data))=={0,415,416,417,431,432,433,447,448,449} and np.count_nonzero(data)==36
sheet=Image.open(SOURCE/'Tiles/ObjectsTiles.png').convert('RGBA')
firstgid=int(root.find("tileset[@source='ObjectsTiles.tsx']").get('firstgid'))
covered=np.zeros((rows,cols),dtype=np.uint8)
for i,city in enumerate(layout['cities'],1):
 assert city['name']==str(i) and city['size']==[96,96]
 obj=next(p for p in points if p.get('name')==str(i))
 x,y,cw,ch=[int(float(obj.get(k))) for k in ['x','y','width','height']]
 assert city['object_id']==int(obj.get('id')) and city['position']==[x+cw/2,y+ch/2]
 tx,ty=city['tile_position'];assert [x,y]==[tx*tw,ty*th]
 assert np.array_equal(data[ty:ty+3,tx:tx+3],[[415,416,417],[431,432,433],[447,448,449]])
 covered[ty:ty+3,tx:tx+3]+=1
 for dy in range(3):
  for dx in range(3):
   local=int(data[ty+dy,tx+dx])-firstgid;sx,sy=(local%16)*tw,(local//16)*th
   sample=np.array(sheet.crop((sx,sy,sx+tw,sy+th)));opaque=sample[:,:,3]==255
   pixels=np.array(actual.crop((x+dx*tw,y+dy*th,x+(dx+1)*tw,y+(dy+1)*th)))
   assert np.array_equal(pixels[opaque],sample[:,:,:3][opaque]),city['name']
assert np.array_equal(covered,(data>0).astype(np.uint8)),'City interaction rectangles omit or add city tiles'
spawns=[o for o in objects.findall('object') if o.get('type')=='PlayerSpawn']
assert len(spawns)==1 and layout['spawn']==[int(float(spawns[0].get(k))) for k in ['x','y']]
assert layout['spawn']==[1408,672]
print('PASS: four exact replacement city sprites/anchors, hidden city rectangles and player spawn')

# Shape-derived navigation must preserve all visual inputs above.
import sys
sys.path.insert(0,str(ROOT/'tools'))
from world_navigation import navigation_data, terrain_masks, transform
nav=layout['navigation'];blocked={tuple(p) for p in nav['blocked']}
assert nav['cell_size']==[4,4] and nav['grid_size']==[640,320]
assert nav['bridge_tiles']==[[39,15],[40,21]]
pixels,mountains,water,_=terrain_masks(root,SOURCE)
coarse=np.zeros((320,640),dtype=bool)
for x,y in blocked:coarse[y,x]=True
expanded=coarse.repeat(4,0).repeat(4,1)
assert expanded[pixels].all(),'A source obstacle pixel was made walkable'
assert np.array_equal(coarse,pixels.reshape(320,4,640,4).any(axis=(1,3)))
def closed(x,y):return (x//4,y//4) in blocked
# Both bridges: actual deck open; water above and below remains closed.
for x,y in [(1264,480),(1296,672)]:
 assert not closed(x,y+16)
 assert closed(x,y+5) and closed(x,y+27)
 assert water[y+16,x] and water[y+5,x] and water[y+27,x]
# Same mountain tile: rock blocked, adjacent transparent grass usable.
assert closed(1180,512) and not closed(1184,512)
assert mountains[512:516,1180:1184].any() and not mountains[512:516,1184:1188].any()
assert not closed(*layout['spawn'])
# Source-relative tile identity, flips, and layer order using original source tiles.
fixture=ET.Element('map',width='2',height='2',tilewidth='32',tileheight='32')
for ref in root.findall('tileset'):fixture.append(copy.deepcopy(ref))
terrain=ET.SubElement(fixture,'layer',name='MisleadingName',width='2',height='2')
ET.SubElement(terrain,'data',encoding='csv').text='589,599,201,1'
road=ET.SubElement(fixture,'layer',name='Overlay',width='2',height='2')
ET.SubElement(road,'data',encoding='csv').text='997,997,997,0'
a,ma,wa,_=terrain_masks(fixture,SOURCE)
assert not a[16,16] and wa[16,16] # dirt on water opens just the path
assert a[3,16] # water beside the road stays blocked
assert a[ma].all() # no road can clear rock
fixture.remove(road);fixture.insert(0,road)
b,_,_,_=terrain_masks(fixture,SOURCE)
assert b[16,16] and np.count_nonzero(b)>np.count_nonzero(a)
fixture.remove(road)
terrain.find('data').text='579,0,0,0'
a,_,_,_=terrain_masks(fixture,SOURCE)
terrain.find('data').text=str(579|0x80000000)+',0,0,0'
b,_,_,_=terrain_masks(fixture,SOURCE)
assert np.array_equal(b[:32,:32],a[:32,:32][:,::-1])
print('PASS: silhouette obstacles, bridge deck/water separation, mountain margins, original palette masks and tile transforms/order')
