#!/usr/bin/env python3
"""Bake the user's traced map: plains, snow, forest, ridges, water and numbered towns."""
from pathlib import Path
import json, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
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
noise=np.array(Image.fromarray(np.random.default_rng(28).integers(0,256,(120,160),dtype=np.uint8)).resize((W//2,H//2),Image.Resampling.BILINEAR).resize((W,H),Image.Resampling.NEAREST))
tone=np.clip((noise.astype(np.int16)-50)//50,0,3).astype(np.uint8)
pal=np.array([
 [[99,126,79],[103,132,82],[108,137,86],[113,141,90]],
 [[211,220,214],[220,228,220],[229,235,226],[236,241,234]],
 [[66,92,49],[71,98,53],[76,104,57],[80,109,60]],
 [[65,77,58],[71,83,63],[78,90,69],[84,96,73]],
 [[76,141,173],[78,144,176],[80,147,179],[82,150,181]],
],dtype=np.uint8)
im=Image.fromarray(pal[biome,tone]);d=ImageDraw.Draw(im)
water=Image.fromarray((biome==4).astype(np.uint8)*255)
# A narrow shoreline, clipped to land and never cutting across the planned water.
bank=np.array(water.filter(ImageFilter.MaxFilter(5)))>0
edge=bank & (biome!=4) & (biome!=3)
a=np.array(im);a[edge & (biome==1)]=[189,211,211];a[edge & (biome!=1)]=[142,153,103]
im=Image.fromarray(a);d=ImageDraw.Draw(im)
for i in range(210000):
 x,y=rng.randrange(W-10),rng.randrange(H-3)
 kind=int(biome[y,x])
 if kind==4:
  if i%7==0:d.line((x,y,x+rng.randrange(2,8),y),fill='#75b0c3')
 elif kind==1:
  if i%3==0:d.line((x,y,x+rng.randrange(1,4),y),fill=rng.choice(['#edf1e6','#c8d5cd']))
 elif kind in (0,2):
  d.line((x,y,x+rng.randrange(1,3),y),fill=rng.choice(['#607b4c','#849d61']) if kind==0 else '#506e3d')
# Rocky ridges viewed from ABOVE: overlapping four-sided rock masses, with
# the summit inside each footprint. Irregular slopes distinguish mountains from roads.
rock=Image.new('RGBA',(W,H));rd=ImageDraw.Draw(rock)
rock_rng=random.Random(719)
for ri,ridge in enumerate(PLAN['mountains']):
 line=smooth(scale_points(ridge['points']))
 half=ridge['width']*W/RW*.48
 stride=max(4,int(half/5))
 summits=[]
 for i in range(0,len(line),stride):
  x,y=line[i]
  before=np.array(line[max(0,i-2)],float);after=np.array(line[min(i+2,len(line)-1)],float)
  tangent=after-before;length=max(1,float(np.linalg.norm(tangent)));t=tangent/length
  n=np.array([-t[1],t[0]])
  center=np.array([x,y],float)
  tip=center+n*rock_rng.uniform(-.27,.27)*half+t*rock_rng.uniform(-8,8)
  extent=half*rock_rng.uniform(.76,1.12)
  # Four irregular feet surround the summit, so no front-facing mountain silhouette.
  feet=[center-t*half*rock_rng.uniform(.75,1.1),center+n*extent,
        center+t*half*rock_rng.uniform(.75,1.1),center-n*extent]
  pts=[tuple(v.astype(int)) for v in feet];peak=tuple(tip.astype(int));summits.append(peak)
  rd.polygon(pts,fill='#3c5141')
  for k in range(4):
   a=feet[k];b=feet[(k+1)%4];outward=(a+b)*.5-tip
   light=float(np.dot(outward,np.array([-1.,-1.])))
   color=('#b5b79e' if light>20 else '#8c9880' if light>0 else '#647661' if light>-20 else '#465c4b')
   if ri==0:color=('#e6e9da' if light>20 else '#c3d0bf' if light>0 else '#97afa4' if light>-20 else '#6f887d')
   rd.polygon([peak,pts[k],pts[(k+1)%4]],fill=color)
   # Broken ledges stop short of the outer boundary, with no regular cross-hatching.
   for fraction in [.4,.66]:
    q=tip+(a-tip)*fraction;r=tip+(b-tip)*(fraction*.8)
    if rock_rng.random()<.55:rd.line([tuple(q.astype(int)),tuple(((q+r)*.5).astype(int))],fill='#6f7d66' if light>0 else '#82957d',width=2)
  # A small jagged summit highlight and one descending lit spur.
  spur=tip+(feet[3]-tip)*.5
  rd.line([peak,(peak[0]-3,peak[1]+2),tuple(spur.astype(int))],fill='#d4d2b5' if ri else '#f0f2e7',width=3)
 for i in range(1,len(summits)):
  if rock_rng.random()<.7:rd.line([summits[i-1],summits[i]],fill='#c0bfa2' if ri else '#e8ece0',width=2)
# Keep generated rock strictly inside the traced mountain polygons.
rock.putalpha(Image.fromarray(np.minimum(np.array(rock.getchannel('A')),((biome==3)*255).astype(np.uint8))))
im.paste(rock,(0,0),rock);d=ImageDraw.Draw(im)

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
data={'size':[W,H],'spawn':[2560,1920],'reference_size':[RW,RH],'numbering':PLAN['numbering'],'terrain_types':['plains','snow','forest','mountains','water'],'resources':RESOURCE_MANIFEST,'tree_counts':tree_counts,'chunks':chunks,'cities':[{'id':id,'name':name,'position':[x,y],'reference_position':PLAN['cities'][i]['position'],'size':[128,128]} for i,(id,name,x,y) in enumerate(CITIES)]}
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
