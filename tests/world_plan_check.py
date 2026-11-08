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
