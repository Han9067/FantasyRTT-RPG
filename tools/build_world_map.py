#!/usr/bin/env python3
"""Import the approved Tiled map at native size; publish cached-render provenance and chunks.

Normal builds need only Pillow. After editing Tiled sources, use --refresh-render
with tmxrasterizer on PATH, or set TILED_RASTERIZER to its executable path.
"""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess
import xml.etree.ElementTree as ET
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/world/tiled'
OUT=ROOT/'assets/world'
MANIFEST=SOURCE/'render-manifest.json'

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def inputs():return sorted([SOURCE/'WorldMap.tmx',*SOURCE.glob('*.tsx'),*(SOURCE/'Tiles').glob('*.png')])

def build(refresh=False):
    manifest=json.loads(MANIFEST.read_text())
    render=SOURCE/manifest['render_file']
    if refresh:
        rasterizer=os.environ.get('TILED_RASTERIZER') or shutil.which('tmxrasterizer')
        if not rasterizer:raise RuntimeError('Install Tiled or set TILED_RASTERIZER for --refresh-render')
        env=dict(os.environ);env.setdefault('QT_QPA_PLATFORM','offscreen')
        subprocess.run([rasterizer,'--no-smoothing',str(SOURCE/'WorldMap.tmx'),str(render)],env=env,check=True)
        manifest['inputs']={p.relative_to(SOURCE).as_posix():sha(p) for p in inputs()}
        manifest['render_sha256']=sha(render)
        MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    actual={p.relative_to(SOURCE).as_posix():sha(p) for p in inputs()}
    if actual!=manifest['inputs'] or sha(render)!=manifest['render_sha256']:
        raise RuntimeError('Tiled inputs/render changed. Run tools/build_world_map.py --refresh-render to rebuild the native map.')
    tmx=ET.parse(SOURCE/'WorldMap.tmx').getroot()
    assert tmx.get('orientation')=='orthogonal' and tmx.get('infinite')=='0'
    tw,th=int(tmx.get('tilewidth')),int(tmx.get('tileheight'))
    cols,rows=int(tmx.get('width')),int(tmx.get('height'))
    w,h=cols*tw,rows*th
    assert w > 0 and h > 0 and tw > 0 and th > 0
    im=Image.open(render).convert('RGB');assert im.size==(w,h)
    objects=tmx.find("objectgroup[@name='GameObjects']")
    assert objects is not None and objects.get('visible')=='0'
    markers=[o for o in objects.findall('object') if o.get('type')=='City']
    cities=[]
    for marker in sorted(markers,key=lambda m:int(m.get('name'))):
        name=marker.get('name')
        x,y,cw,ch=[int(float(marker.get(key))) for key in ('x','y','width','height')]
        assert 0<=x<x+cw<=w and 0<=y<y+ch<=h
        assert x%tw==y%th==cw%tw==ch%th==0
        cities.append({'id':f'city_{int(name):02}','name':name,'object_id':int(marker.get('id')),'position':[x+cw/2,y+ch/2],'size':[cw,ch],'tile_position':[x//tw,y//th]})
    assert cities and [c['name'] for c in cities]==list(map(str,range(1,len(cities)+1)))
    spawns=[o for o in objects.findall('object') if o.get('type')=='PlayerSpawn']
    assert len(spawns)==1
    spawn=[int(float(spawns[0].get(key))) for key in ('x','y')]
    assert 18<=spawn[0]<=w-18 and 32<=spawn[1]<=h-18
    chunks_dir=OUT/'chunks';chunks_dir.mkdir(parents=True,exist_ok=True);chunks=[]
    for y in range(0,h,2048):
        for x in range(0,w,2048):
            name=f'world_{x//2048}_{y//2048}.png';part=im.crop((x,y,min(x+2048,w),min(y+2048,h)))
            part.save(chunks_dir/name,optimize=True)
            chunks.append({'file':'chunks/'+name,'position':[x,y],'size':list(part.size)})
    wanted={Path(chunk['file']).name for chunk in chunks}
    for stale in chunks_dir.glob('world_*.png'):
        if stale.name not in wanted:
            stale.unlink()
            stale.with_suffix('.png.import').unlink(missing_ok=True)
    mini_size=(min(1024,w),max(1,round(h*min(1024,w)/w)))
    im.resize(mini_size,Image.Resampling.NEAREST).save(OUT/'imperial_world.png',optimize=True)
    layout={'size':[w,h],'spawn':spawn,'source':'art/world/tiled/WorldMap.tmx','render_sha256':sha(render),'tile_size':[tw,th],'grid_size':[cols,rows],'minimap_size':list(mini_size),'terrain_types':['plains','forest','mountains','water'],'cities':cities,'chunks':chunks}
    (OUT/'world_layout.json').write_text(json.dumps(layout,ensure_ascii=False,indent=2)+'\n')
    review_width=min(1600,w);review_height=round(h*review_width/w)
    review=im.resize((review_width,review_height),Image.Resampling.NEAREST);d=ImageDraw.Draw(review)
    font=ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansCJK-Regular.ttc'),15)
    for city in cities:
        x,y=[v*review_width/w for v in city['position']];dy=city['size'][1]*0.5*review_width/w+4
        if y+dy+20>review_height:dy=-dy-20
        d.text((x,y+dy),city['name'],font=font,anchor='mt',fill='#ffe6aa',stroke_width=2,stroke_fill='#263025')
    review.save(ROOT/'docs/world/numbered-world-plan.png')
    print(f'Imported approved Tiled world {w}x{h}; {len(cities)} cities from hidden GameObjects; {len(chunks)} unchanged-pixel chunks')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--refresh-render',action='store_true')
    build(parser.parse_args().refresh_render)
