#!/usr/bin/env python3
"""Deterministic, native-pixel world art. No purchased character pixels are changed."""
from pathlib import Path
import json, math, random
import numpy as np
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/world'
W,H=3072,2304
rng=random.Random(82317)
CITIES=[
 ('westmark','베스트마르크',500,880,'Aachen / western marches'),
 ('rheinhafen','라인하펜',770,650,'Cologne / Rhine trade'),
 ('nordhafen','노르트하펜',1500,360,'Hamburg / northern lowlands'),
 ('elbenwacht','엘벤바흐트',2030,650,'Magdeburg / Elbe crossing'),
 ('falkenfurt','팔켄푸르트',1130,1000,'Frankfurt / Main confluence'),
 ('rabenburg','라벤부르크',1540,1220,'Nuremberg / central trade routes'),
 ('waldheim','발트하임',690,1480,'Strasbourg / upper Rhine'),
 ('bohenfels','보헨펠스',2370,1120,'Prague / Bohemian basin'),
 ('donauwacht','도나우바흐트',1880,1510,'Regensburg / Danube'),
 ('ostkrone','오스트크로네',2640,1640,'Vienna / eastern Danube'),
 ('augsfeld','아우크스펠트',1360,1700,'Augsburg / Alpine foreland'),
 ('passburg','파스부르크',1650,2110,'Trento / Alpine pass'),
]
# Deliberately compressed fictional courses; not a historical border reconstruction.
RIVERS=[
 [(1010,1970),(960,1810),(880,1700),(850,1510),(830,1300),(780,1100),(830,920),(700,760),(660,560),(540,340),(390,170),(120,90)],
 [(1080,1620),(1270,1550),(1500,1560),(1730,1480),(1970,1570),(2210,1510),(2450,1610),(2800,1710),(3072,1780)],
 [(2420,1460),(2390,1260),(2240,1070),(2180,900),(2110,750),(1900,580),(1770,430),(1670,220),(1560,0)],
 [(1570,1250),(1410,1140),(1280,1180),(1110,1130),(960,1140),(780,1100)],
 [(2440,1330),(2510,1120),(2450,940),(2320,820),(2180,900)],
]
ROUTES=[(0,1),(0,4),(1,4),(1,2),(2,3),(3,7),(3,5),(4,5),(4,6),(5,7),(5,8),(5,10),(6,10),(8,9),(8,10),(7,9),(10,11)]

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
# Sampled noise and a small shared palette yield crisp native-pixel ground.
small=np.random.default_rng(28).integers(0,256,(72,96),dtype=np.uint8)
noise=np.array(Image.fromarray(small).resize((W//2,H//2),Image.Resampling.BILINEAR))
tone=np.clip((noise.astype(float)-35)//40,0,4).astype(int)
pal=np.array([[83,113,68],[91,122,73],[99,129,79],[106,135,84],[114,140,89]],dtype=np.uint8)
im=Image.fromarray(pal[tone]).resize((W,H),Image.Resampling.NEAREST)
d=ImageDraw.Draw(im)
for i in range(130000):
 x,y=rng.randrange(W),rng.randrange(H)
 d.line((x,y,x+rng.randrange(1,3),y),fill=rng.choice(['#617d4b','#78905a','#8b9c65','#536e43']))
# Distinct northern coastal marsh / pale shore.
coast=smooth([(0,245),(200,190),(310,270),(490,210),(620,260),(780,165),(970,210),(1140,100),(1350,160),(1550,85),(1740,105),(1810,0)])
d.polygon([(0,0)]+coast+[(W,0)],fill='#b0aa78')
d.polygon([(0,0)]+[(x,y-15) for x,y in coast]+[(W,0)],fill='#426c76')
d.line([(x,y-13) for x,y in coast],fill='#81aaa1',width=3)
water=Image.new('1',(W,H));wd=ImageDraw.Draw(water)
wd.polygon([(0,0)]+coast+[(W,0)],fill=1)
for i in range(1400):
 x,y=rng.randrange(1800),rng.randrange(250)
 if water.getpixel((x,y)):d.line((x,y,x+rng.randrange(3,12),y),fill='#55818a')
sea_base=im.copy()
sea_mask=Image.new('1',(W,H))
ImageDraw.Draw(sea_mask).polygon([(0,0)]+[(x,y-15) for x,y in coast]+[(W,0)],fill=1)
# Rivers have muddy banks, blue-green shallow edges, dark channels and broken glints.
for idx,pts in enumerate(RIVERS):
 line=smooth(pts);width=20 if idx<3 else 12
 d.line(line,fill='#8f9869',width=width+12,joint='curve')
 d.line(line,fill='#467a7c',width=width+4,joint='curve')
 d.line(line,fill='#568c93',width=width,joint='curve')
 d.line(line,fill='#426f80',width=max(4,width-9),joint='curve')
 wd.line(line,fill=1,width=width+14)
 for x,y in line[::7]:d.line((x-2,y-2,x+3,y-2),fill='#8db5ad')
# River banks stop at the estuary rather than extending as jetties into the sea.
im.paste(sea_base,(0,0),sea_mask)
roadmask=Image.new('1',(W,H));rd=ImageDraw.Draw(roadmask)
for a,b in ROUTES:
 _,_,ax,ay,_=CITIES[a];_,_,bx,by,_=CITIES[b]
 points=smooth([(ax,ay+64),((ax+bx)//2+40,(ay+by)//2+45),(bx,by+64)])
 d.line(points,fill='#8b8960',width=16,joint='curve');d.line(points,fill='#b29d6d',width=10,joint='curve');d.line(points,fill='#c1ad7b',width=4,joint='curve')
 rd.line(points,fill=1,width=40)
 # Bridge planks only at the portions actually crossing water.
 for n,(x,y) in enumerate(points):
  if 0<=x<W and 0<=y<H and water.getpixel((x,y)):
   if n%2==0:
    nxt=points[min(n+1,len(points)-1)];dx,dy=nxt[0]-x,nxt[1]-y;l=max(1,math.hypot(dx,dy));px,py=-dy/l*9,dx/l*9
    d.line((int(x-px),int(y-py),int(x+px),int(y+py)),fill='#665442',width=3)
    d.line((int(x-px),int(y-py)-1,int(x+px),int(y+py)-1),fill='#bea078',width=1)

def blocked(x,y,r=100):
 return any(abs(x-c[2])<r and abs(y-c[3])<r for c in CITIES) or abs(x-1536)<55 and abs(y-1120)<50
# Fields around towns, leaving all roads and riverbanks clear.
for _,_,cx,cy,_ in CITIES:
 for n in range(8):
  x=cx+rng.choice([-1,1])*rng.randint(95,205);y=cy+rng.randint(-100,160)
  if not (25<x<W-70 and 300<y<H-50):continue
  if any(water.getpixel((x+dx,y+dy)) or roadmask.getpixel((x+dx,y+dy)) for dx in (0,48) for dy in (0,24)):continue
  d.rectangle((x,y,x+48,y+24),fill=rng.choice(['#93905b','#9e9561','#7e8952']))
  for yy in range(y+2,y+23,4):d.line((x+2,yy,x+45,yy),fill='#b1a471')
  d.line((x,y+25,x+48,y+25),fill='#526947')
# Layered hills, Bohemian rim and Alpine wall. Peaks remain individual pixel clusters.
def mountain(x,y,h,w,snow=False):
 pts=[(x-w,y),(x-w*3//4,y-h//3),(x-w//2,y-h*2//5),(x-9,y-h*4//5),(x,y-h),(x+12,y-h*4//5),(x+w//2,y-h//2),(x+w,y)]
 d.polygon([(a+5,b+5) for a,b in pts],fill='#466444')
 d.polygon(pts,fill='#46584f');d.polygon([(x-w+3,y-2),(x-w//2,y-h*2//5+3),(x-9,y-h*4//5+4),(x,y-h+3),(x-4,y-h//2),(x-16,y-8)],fill='#9a9b7c')
 d.polygon([(x,y-h+3),(x+12,y-h*4//5+3),(x+w//2,y-h//2),(x+8,y-h//3),(x-4,y-h//2)],fill='#748374')
 for j in range(35):
  yy=rng.randrange(8,max(9,h-8));frac=1-yy/h;xx=x+rng.randint(-max(1,int(w*frac)),max(1,int(w*frac)))
  if xx<x-5:d.line((xx,y-yy,xx+rng.randint(2,6),y-yy),fill='#b0ad89')
  else:d.line((xx,y-yy,xx+3,y-yy),fill='#556b5c')
 if snow:
  d.polygon([(x-12,y-h+23),(x,y-h+2),(x+15,y-h+26),(x+5,y-h+21),(x,y-h+29),(x-5,y-h+19)],fill='#d9d9bb')
  d.line((x,y-h+4,x+5,y-h+19),fill='#a5bdb1',width=3)
mountains=[]
for i in range(57):
 x=240+i*49;y=1970+int(math.sin(i*.23)*48)+rng.randrange(-20,70)
 if 1510<x<1780:continue # southern pass
 mountains.append((x,y,rng.randrange(85,166),rng.randrange(42,73),True))
for i in range(36):
 angle=i*math.tau/36;x=int(2380+math.cos(angle)*440);y=int(1110+math.sin(angle)*420)
 if i%9 in (0,1):continue
 mountains.append((x,y,rng.randrange(48,90),rng.randrange(28,48),False))
for i in range(25):
 x=1040+i*32;y=830+int(math.sin(i*.28)*110)
 mountains.append((x,y,rng.randrange(40,78),rng.randrange(24,44),False))
for i in range(17):
 x=480+int(math.sin(i*.3)*75);y=1270+i*26
 mountains.append((x,y,rng.randrange(50,88),rng.randrange(28,46),False))
# Mixed beech/oak silhouettes on the lowlands, conifers in uplands.
def tree(x,y,pine=False):
 d.ellipse((x-9,y-2,x+12,y+4),fill='#405c3c');d.rectangle((x-1,y-9,x+2,y),fill='#514936');d.line((x,y-7,x,y-1),fill='#a68c58')
 if pine:
  for k in range(3):
   yy=y-7-k*7;ww=10-k*2
   d.polygon([(x-ww,yy),(x,yy-13),(x+ww,yy)],fill='#2f493b')
   d.polygon([(x-ww+2,yy-2),(x,yy-11),(x+ww-3,yy-2)],fill='#52744c')
   d.line((x-ww+3,yy-3,x-1,yy-3),fill='#789356')
 else:
  for dx,dy,rr in [(-5,-16,8),(5,-18,8),(0,-25,8),(0,-12,7)]:
   pts=[(x+dx-rr,y+dy-3),(x+dx-rr+3,y+dy-rr),(x+dx+3,y+dy-rr),(x+dx+rr,y+dy-3),(x+dx+rr-1,y+dy+5),(x+dx-3,y+dy+rr),(x+dx-rr,y+dy+3)]
   d.polygon(pts,fill='#304d37');d.polygon([(a,b-2) for a,b in pts[1:-1]],fill='#537846')
   d.rectangle((x+dx-4,y+dy-5,x+dx+1,y+dy-3),fill='#7d9856')
   d.line((x+dx+2,y+dy+3,x+dx+5,y+dy+3),fill='#42643d')
forests=[(480,1170,280,410),(1180,750,380,160),(1730,970,190,230),(2180,1310,210,200),(2700,830,220,390),(1040,1880,370,120),(2070,1910,450,120),(420,520,240,200),(1630,430,170,180)]
objects=[]
for n in range(13000):
 x,y=rng.randrange(30,W-30),rng.randrange(310,H-35)
 density=max(math.exp(-(((x-cx)/rx)**2+((y-cy)/ry)**2)*1.7) for cx,cy,rx,ry in forests)
 if rng.random()>density*.8 or blocked(x,y) or water.getpixel((x,y)) or roadmask.getpixel((x,y)):continue
 objects.append((y,'tree',(x,y,y>1750 or rng.random()<.25)))
for m in mountains:
 if not blocked(m[0],m[1],130) and not roadmask.getpixel((m[0],m[1])):objects.append((m[1],'mountain',m))
for _,kind,args in sorted(objects):
 if kind=='tree':tree(*args)
 else:mountain(*args)
for i,(_,name,x,y,_) in enumerate(CITIES):
 city=city_sprite(i);city.save(OUT/f'city_{i%4}.png') if i<4 else None
 im.paste(city,(x-64,y-64),city)
im.save(OUT/'imperial_world.png',optimize=True)
data={'size':[W,H],'spawn':[1536,1120],'cities':[{'id':id,'name':name,'position':[x,y],'size':[128,128],'inspiration':inspiration} for id,name,x,y,inspiration in CITIES]}
(OUT/'world_layout.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
im.resize((1024,768),Image.Resampling.NEAREST).save('/tmp/world023-overview.png')
print(f'World: {W}x{H}, {len(CITIES)} cities at 128x128, {len(objects)} static terrain decorations')
