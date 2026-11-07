#!/usr/bin/env python3
"""Bake the 40-city grass/coast prototype in web-safe native-pixel chunks."""
from pathlib import Path
import json, math, random
import numpy as np
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world'
W,H=5120,3840
CHUNK=2048
rng=random.Random(82317)
NAMES=[
 '노르트하펜','베르겐','프리젠','엘벤바흐트','노르트펠스','발덴하펜','오스트하펜','그라이펜',
 '베스트마르크','라인하펜','린덴부르크','하이덴','로젠펠트','아이헨','보헨펠스','실버크로네',
 '팔켄푸르트','슈타인하임','크로넨','라벤부르크','알텐부르크','그뤼네발트','로텐펠스','오스트마르크',
 '발트하임','아우크스펠트','벨렌','도나우바흐트','호헨베르크','아이젠','오스트크로네','발켄하임',
 '쥐트마르크','도른펠스','파스부르크','아들러','브룬넨','에렌펠스','슈바넨','쥐트크로네',
]
placement=random.Random(4024)
CITIES=[]
for index,name in enumerate(NAMES):
 row,col=divmod(index,8)
 x=330+col*630+(60 if row%2 else 0)+placement.randint(-85,85)
 y=650+row*660+placement.randint(-90,90)
 CITIES.append((f'city_{index+1:02d}',name,x,y))

def smooth(points):
 out=[]
 for i in range(len(points)-1):
  p0=np.array(points[max(i-1,0)],float);p1=np.array(points[i],float)
  p2=np.array(points[i+1],float);p3=np.array(points[min(i+2,len(points)-1)],float)
  for t in np.linspace(0,1,max(4,int(np.linalg.norm(p2-p1)/5)),endpoint=False):
   q=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
   out.append(tuple(q.astype(int)))
 out.append(tuple(points[-1]));return out

def city_sprite(index):
 im=Image.new('RGBA',(128,128));d=ImageDraw.Draw(im)
 def rect(b,c):d.rectangle(b,fill=c)
 dark='#343e39'; stone='#9fa58b';light='#c3c5a3';shadow='#727e71'
 roof=['#995b42','#765344','#875344','#666c69'][index%4]
 flag=['#aa4d3e','#536c99','#b3974b','#667b4b'][index%4]
 rect((6,10,124,126),'#354e3e');rect((4,9,119,121),'#697b54')
 rect((13,19,109,108),'#9c9874');rect((58,21,68,114),'#c0b08a');rect((17,66,109,75),'#b9ab82')
 # Tiny courtyard pavers.
 for y in range(26,109,7):
  for x in range(22,106,9):
   if rng.random()<.36:rect((x,y,x+2,y+1),'#b7aa82')
 def wall(x,y,w,h):
  rect((x-1,y-1,x+w,y+h),dark);rect((x,y,x+w-1,y+h-1),shadow)
  rect((x,y,x+w-2,y+3),light)
  for yy in range(y+6,y+h,5):
   for xx in range(x+1+(3 if yy%2 else 0),x+w-4,7):
    rect((xx,yy,xx+5,yy+2),stone)
 def roof_house(x,y,w=19,h=17):
  rect((x+3,y+4,x+w+2,y+h+2),'#777956');rect((x,y,x+w,y+h),dark)
  rect((x+1,y+1,x+w-1,y+h-1),'#c8b791');rect((x+2,y+8,x+w-2,y+9),'#6b5945')
  rect((x+2,y+2,x+3,y+h-1),'#6b5945');rect((x+w-5,y+5,x+w-2,y+9),'#37423e')
  rect((x+7,y+h-7,x+10,y+h),'#5a493b')
  d.polygon([(x-2,y+2),(x+w//2,y-9),(x+w+2,y+2)],fill=dark)
  d.polygon([(x,y),(x+w//2,y-7),(x+w,y)],fill=roof)
  for r in range(3):rect((x+w//2-r*3,y-5+r*2,x+w//2+r*3,y-5+r*2),'#bc8259')
  rect((x+w-4,y-7,x+w-2,y-1),'#72776b')
 wall(16,17,95,9)
 for x,y in [(25,42),(79,45),(25,80),(80,82)]:roof_house(x,y)
 # A keep with a steep tiled roof, inside the city walls.
 wall(50,33,28,25);roof_house(49,32,29,25)
 rect((59,42,65,56),dark);rect((60,43,62,53),'#b38a59')
 wall(11,26,8,82);wall(108,26,8,82);wall(14,104,99,15)
 for x in range(16,110,8):
  rect((x,13,x+4,19),dark);rect((x+1,13,x+4,17),light)
  rect((x,100,x+4,106),dark);rect((x+1,100,x+4,104),light)
 for y in range(28,101,8):
  rect((9,y,14,y+4),light);rect((107,y,112,y+4),light)
 # Four corner towers, footprint kept inside the exact 128x128 canvas.
 for x,y in [(5,11),(101,11),(5,96),(101,96)]:
  wall(x,y,20,25)
  for dx in (0,8,16):
   rect((x+dx-1,y-5,x+dx+4,y+1),dark);rect((x+dx,y-5,x+dx+3,y-1),light)
  rect((x+8,y+9,x+11,y+16),dark);rect((x+9,y+9,x+10,y+14),'#566858')
 # South gate, timber portcullis and path.
 rect((54,104,73,120),dark);rect((57,105,70,120),'#72583e')
 for x in range(58,71,4):rect((x,106,x,120),'#b19465')
 rect((55,119,72,126),'#bea375');rect((55,122,72,122),'#857250')
 rect((112,0,113,13),dark);rect((114,1,125,7),flag);rect((114,1,116,7),'#d6b878')
 return im

OUT.mkdir(parents=True,exist_ok=True)
chunks_dir=OUT/'chunks'
chunks_dir.mkdir(exist_ok=True)
small=np.random.default_rng(28).integers(0,256,(120,160),dtype=np.uint8)
noise=np.array(Image.fromarray(small).resize((W//2,H//2),Image.Resampling.BILINEAR))
tone=np.clip((noise.astype(float)-35)//40,0,4).astype(int)
pal=np.array([[83,113,68],[91,122,73],[99,129,79],[106,135,84],[114,140,89]],dtype=np.uint8)
im=Image.fromarray(pal[tone]).resize((W,H),Image.Resampling.NEAREST)
d=ImageDraw.Draw(im)
for i in range(240000):
 x,y=rng.randrange(W),rng.randrange(H)
 d.line((x,y,x+rng.randrange(1,3),y),fill=rng.choice(['#617d4b','#78905a','#8b9c65','#536e43']))
# Preserve the northern coastline's broad silhouette; there are no inland rivers.
coast=smooth([(int(x*W/3072),int(y*H/2304)) for x,y in [(0,245),(200,190),(310,270),(490,210),(620,260),(780,165),(970,210),(1140,100),(1350,160),(1550,85),(1740,105),(1810,0)]])
d.polygon([(0,0)]+coast+[(W,0)],fill='#b0aa78')
d.polygon([(0,0)]+[(x,y-15) for x,y in coast]+[(W,0)],fill='#426c76')
d.line([(x,y-13) for x,y in coast],fill='#81aaa1',width=3)
water=Image.new('1',(W,H));wd=ImageDraw.Draw(water)
wd.polygon([(0,0)]+coast+[(W,0)],fill=1)
for i in range(3200):
 x,y=rng.randrange(3000),rng.randrange(450)
 if water.getpixel((x,y)):d.line((x,y,x+rng.randrange(3,12),y),fill='#55818a')
for i,(_,name,x,y) in enumerate(CITIES):
 assert 64<=x<W-64 and 64<=y<H-64
 assert not water.crop((x-80,y-80,x+80,y+80)).getbbox(),name+' overlaps coast'
 for _,other,ox,oy in CITIES[:i]:assert math.hypot(x-ox,y-oy)>400,(name,other)
 city=city_sprite(i)
 if i<4:city.save(OUT/f'city_{i}.png')
 im.paste(city,(x-64,y-64),city)
chunks=[]
for y in range(0,H,CHUNK):
 for x in range(0,W,CHUNK):
  filename=f'world_{x//CHUNK}_{y//CHUNK}.png'
  part=im.crop((x,y,min(x+CHUNK,W),min(y+CHUNK,H)))
  part.save(chunks_dir/filename,optimize=True)
  chunks.append({'file':'chunks/'+filename,'position':[x,y],'size':list(part.size)})
# Small overview only. Runtime ground uses native-pixel chunks, never this downsample.
im.resize((1024,768),Image.Resampling.NEAREST).save(OUT/'imperial_world.png',optimize=True)
data={'size':[W,H],'spawn':[2560,1920],'chunks':chunks,'cities':[{'id':id,'name':name,'position':[x,y],'size':[128,128]} for id,name,x,y in CITIES]}
(OUT/'world_layout.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print(f'World: {W}x{H}, {len(CITIES)} native 128px cities, {len(chunks)} chunks <=2048px; grass and sea only')
