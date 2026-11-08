#!/usr/bin/env python3
"""Bake the user's traced map: plains, snow, forest, ridges, water and numbered towns."""
from pathlib import Path
import json, random
import numpy as np
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world'
PLAN_PATH = ROOT / 'art/world/user_plan_2026_11_08.json'
PLAN = json.loads(PLAN_PATH.read_text())
W,H = PLAN['world_size']
RW,RH = PLAN['reference_size']
CHUNK=2048
rng=random.Random(82317)
CITIES=[(c['id'],c['name'],round(c['position'][0]*W/RW),round(c['position'][1]*H/RH)) for c in PLAN['cities']]

def scale_points(points):
 return [(round(x*W/RW),round(y*H/RH)) for x,y in points]

def smooth(points):
 out=[]
 for i in range(len(points)-1):
  p0=np.array(points[max(i-1,0)],float);p1=np.array(points[i],float)
  p2=np.array(points[i+1],float);p3=np.array(points[min(i+2,len(points)-1)],float)
  for t in np.linspace(0,1,max(4,int(np.linalg.norm(p2-p1)/5)),endpoint=False):
   q=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
   out.append(tuple(q.astype(int)))
 out.append(tuple(points[-1]));return out

RESOURCE_DIR = ROOT / 'art/world/resources'
CITY_IMAGE = Image.open(RESOURCE_DIR/'city.png').convert('RGBA')
TREE_IMAGES = [Image.open(RESOURCE_DIR/name).convert('RGBA') for name in ['tree1.png','tree2.png']]
TREE_BOUNDS = [image.getchannel('A').getbbox() for image in TREE_IMAGES]
TREE_ALPHA = [np.array(image.getchannel('A'))>0 for image in TREE_IMAGES]
RESOURCE_MANIFEST = json.loads((RESOURCE_DIR/'manifest.json').read_text())
assert CITY_IMAGE.size == (128,128)
assert all(image.size == (48,48) for image in TREE_IMAGES)
# Tree canvases share a trunk anchor at (24,45); never resize/recolour the source.
tree_counts = [0,0]
tree_proofs = []

OUT.mkdir(parents=True,exist_ok=True)
chunks_dir=OUT/'chunks'
chunks_dir.mkdir(exist_ok=True)
# Semantic masks preserve the user's terrain plan; no random biome placement.
biomes=Image.new('L',(W,H),0)
bd=ImageDraw.Draw(biomes)
def fill_regions(regions,kind):
 for points in regions:
  pts=scale_points(points)
  bd.polygon(smooth(pts+[pts[0]]),fill=kind)
fill_regions(PLAN['snow'],1)
fill_regions(PLAN['forests'],2)
fill_regions(PLAN['seas']+[PLAN['lake']],4)
for river in PLAN['rivers']:
 line=smooth(scale_points(river['points']))
 width=round(river['width']*W/RW)
 bd.line(line,fill=4,width=width,joint='curve')
 # Round endpoints, consistent with the hand-painted reference.
 for x,y in (line[0],line[-1]):bd.ellipse((x-width//2,y-width//2,x+width//2,y+width//2),fill=4)
for ridge in PLAN['mountains']:
 line=smooth(scale_points(ridge['points']))
 width=round(ridge['width']*W/RW)
 bd.line(line,fill=3,width=width,joint='curve')
 for x,y in (line[0],line[-1]):bd.ellipse((x-width//2,y-width//2,x+width//2,y+width//2),fill=3)
# Town markers replace underlying terrain: clear only woodland directly under towns.
city_mask=Image.new('L',(W,H));cd=ImageDraw.Draw(city_mask)
for _,_,x,y in CITIES:cd.ellipse((x-88,y-88,x+88,y+100),fill=255)
biome=np.array(biomes)
biome[(biome==2)&(np.array(city_mask)>0)]=0
biomes=Image.fromarray(biome)
# Build native 32px campaign tiles with corner transitions, then bake for six static draws.
from world_tiles import render_tiles
im, biomes, tile_info = render_tiles(biomes, ROOT/'art/world/tiles')
biome=np.array(biomes)
# Ground generation uses its own RNG so object placements remain deterministic.
d=ImageDraw.Draw(im)

def city_clear(x,y,pad=95):
 return any(abs(x-cx)<pad and abs(y-cy)<pad+18 for _,_,cx,cy in CITIES)

def tree(x,y,pine=False):
 index=1 if pine else 0
 sprite=TREE_IMAGES[index]
 left,top=x-24,y-45
 bx0,by0,bx1,by1=TREE_BOUNDS[index]
 if left+bx0<0 or top+by0<0 or left+bx1>W or top+by1>H:return False
 occupied=TREE_ALPHA[index][by0:by1,bx0:bx1]
 region=biome[top+by0:top+by1,left+bx0:left+bx1]
 if np.any(occupied & (region!=2)):return False
 im.paste(sprite,(left,top),sprite)
 tree_counts[index]+=1
 # Collect locations for independently checking exact source pixels after baking.
 tree_proofs.append({'file':f'tree{index+1}.png','position':[left,top]})
 return True

# Jittered rows give dense stands, baked into the ground; no per-tree runtime nodes.
forest_count=0
for yy in range(40,H-8,23):
 for xx in range(16,W-16,23):
  x=xx+rng.randint(-8,8);y=yy+rng.randint(-6,6)
  if biome[y,x]!=2 or city_clear(x,y) or rng.random()<.12:continue
  if any(biome[py,px]!=2 for px,py in [(x-11,y-18),(x+11,y-18),(x,y-39)]):continue
  if tree(x,y,y<H*.3 or rng.random()<.28):forest_count+=1
# Exact town positions from the red markers; no generated extra cities.
for i,(_,name,x,y) in enumerate(CITIES):
 assert 64<=x<=W-64 and 64<=y<=H-64,(name,x,y)
 assert biome[y,x] in (0,1),(name,'city center is not plains/snow',int(biome[y,x]))
 for _,other,ox,oy in CITIES[:i]:assert abs(x-ox)>=128 or abs(y-oy)>=128,(name,other)
 im.paste(CITY_IMAGE,(x-64,y-64),CITY_IMAGE)
chunks=[]
for y in range(0,H,CHUNK):
 for x in range(0,W,CHUNK):
  filename=f'world_{x//CHUNK}_{y//CHUNK}.png'
  part=im.crop((x,y,min(x+CHUNK,W),min(y+CHUNK,H)))
  part.save(chunks_dir/filename,optimize=True)
  chunks.append({'file':'chunks/'+filename,'position':[x,y],'size':list(part.size)})
im.resize((1024,768),Image.Resampling.NEAREST).save(OUT/'imperial_world.png',optimize=True)
data={'size':[W,H],'spawn':[2560,1920],'reference_size':[RW,RH],'numbering':PLAN['numbering'],'terrain_types':['plains','snow','forest','mountains','water'],'resources':RESOURCE_MANIFEST,'tree_counts':tree_counts,'terrain_tiles':tile_info,'chunks':chunks,'cities':[{'id':id,'name':name,'position':[x,y],'reference_position':PLAN['cities'][i]['position'],'size':[128,128]} for i,(id,name,x,y) in enumerate(CITIES)]}
(OUT/'world_layout.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
# Source-size biome reference and numbered review map, neither exported as runtime texture.
review_dir=ROOT/'docs/world'
review_dir.mkdir(parents=True,exist_ok=True)
(ROOT/'builds').mkdir(exist_ok=True)
(ROOT/'builds/world-tree-placements.json').write_text(json.dumps(tree_proofs,separators=(',',':'))+'\n')
biomes.resize((RW,RH),Image.Resampling.NEAREST).save(review_dir/'plan-biomes.png')
review=im.resize((RW,RH),Image.Resampling.NEAREST);rv=ImageDraw.Draw(review)
from PIL import ImageFont
font=ImageFont.truetype(str(ROOT/'assets/fonts/NotoSansCJK-Regular.ttc'),18)
for i,(_,name,x,y) in enumerate(CITIES):
 sx,sy=PLAN['cities'][i]['position']
 label_y=sy+28 if sy+50<RH else sy-42
 rv.text((sx,label_y),name,font=font,fill='#fff0ba',stroke_width=2,stroke_fill='#25352a',anchor='mt')
review.save(review_dir/'numbered-world-plan.png')
print(f'World: {W}x{H}, {len(CITIES)} numbered cities from red markers; {forest_count} supplied trees ({tree_counts}); {len(chunks)} chunks')
