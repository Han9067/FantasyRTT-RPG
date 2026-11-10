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

# Navigation is derived without editing the supplied map. Both visible bridges stay open.
nav=layout['navigation']
blocked={tuple(p) for p in nav['blocked']};bridges={tuple(p) for p in nav['bridges']}
assert nav['cell_size']==[32,32] and nav['grid_size']==[80,40]
assert bridges=={(39,15),(40,21)} and len(blocked)==162
assert len(nav['mountains'])==56 and len(nav['water'])==119
assert all(tuple(p) in blocked for p in nav['mountains'])
assert all(tuple(p) in blocked or tuple(p) in bridges for p in nav['water'])
assert not bridges & blocked
bridge_layer=root.find("layer[@name='Ect']/data")
bridge_tiles=[int(v) for v in bridge_layer.text.replace('\n','').split(',') if v.strip()]
assert {(i%cols,i//cols) for i,gid in enumerate(bridge_tiles) if gid==317}==bridges
# Small stacked-layer fixtures verify tile identity, source-relative IDs and road priority.
import sys
sys.path.insert(0,str(ROOT/'tools'))
from world_navigation import navigation_data
fixture=ET.Element('map',width='2',height='2',tilewidth='32',tileheight='32')
for ref in root.findall('tileset'):fixture.append(copy.deepcopy(ref))
terrain=ET.SubElement(fixture,'layer',name='MisleadingName',width='2',height='2')
ET.SubElement(terrain,'data',encoding='csv').text='579,599,201,1'
road=ET.SubElement(fixture,'layer',name='Overlay',width='2',height='2')
ET.SubElement(road,'data',encoding='csv').text='2147484597,949,949,0' # flipped road GID 949
sample=navigation_data(fixture,SOURCE)
assert sample['blocked']==[[1,0]] and sample['bridges']==[[0,0],[0,1]]
fixture.remove(road);fixture.insert(0,road)
sample=navigation_data(fixture,SOURCE)
assert sample['bridges']==[] and sample['blocked']==[[0,0],[1,0],[0,1]]
print('PASS: actual water/mountain tile identities, both bridge overrides, flipped tiles and layer-order priority')
