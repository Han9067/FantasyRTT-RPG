"""Native pixel campaign tiles. 32px ground, 16px corner transitions, 64px rock clusters.
No blurred noise, anti-aliasing or transforms of user-supplied objects.
"""
import json
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TILE = 32
# Muted ground under the supplied 48px trees. Warm greys follow the city masonry.
PALETTES = [
 ('#58783f','#53723b','#608044','#6a8b4b','#476737'),
 ('#d9e0d5','#d1dacd','#e5e9df','#f0eee4','#b9c9c2'),
 ('#3f6037','#395930','#46693b','#537646','#304d30'),
 ('#686958','#5c604f','#787869','#929080','#444a3e'),
 ('#386575','#345e70','#3e7080','#588c96','#284b60'),
]

def ground(kind, variant):
    rng = random.Random(4100 + kind*71 + variant)
    p = PALETTES[kind]
    im = Image.new('RGB',(TILE,TILE),p[0]); d = ImageDraw.Draw(im)
    # Small grouped pixels, not evenly sprinkled single-pixel noise.
    for i in range(3 if kind!=4 else 2):
        x,y = rng.randrange(3,24),rng.randrange(4,26)
        if kind in (0,2):
            d.line([(x-2,y+1),(x+5,y+1)],fill=p[1])
            if variant%4!=0:
                d.line([(x,y),(x-1,y-2)],fill=p[2])
                d.line([(x+2,y),(x+2,y-3)],fill=p[2])
                d.point((x+2,y-3),fill=p[3])
                d.line([(x+4,y),(x+5,y-1)],fill=p[2])
        elif kind==1:
            d.line([(x,y),(x+4,y)],fill=p[1]);d.line([(x+1,y-1),(x+5,y-1)],fill=p[2])
        elif kind==3:
            d.line([(x,y),(x+4,y)],fill=p[1]);d.point((x+4,y-1),fill=p[2])
        else:
            d.line([(x,y),(x+5,y)],fill=p[2]);d.line([(x+3,y-1),(x+7,y-1)],fill=p[2])
            if variant%3==0:d.line([(x+4,y-1),(x+6,y-1)],fill=p[3])
    return im


def mountain(variant, snow=False):
    """Overhead 64px crag: an internal summit, four descending spurs, chipped ledges."""
    im=Image.new('RGBA',(64,64)); d=ImageDraw.Draw(im)
    outline,deep,shadow,base,light,shine=('#302f2b','#454640','#5c5d55','#79796f','#a09e8f','#c0bcaa')
    if snow:outline,deep,shadow,base,light,shine=('#455352','#617773','#859b92','#afc0b3','#d6ded1','#eeeee2')
    # Each variant has a different footprint and summit, all drawn in native pixels.
    shapes=[
      [(4,30),(9,25),(9,20),(17,17),(20,10),(28,7),(35,10),(40,8),(46,14),(47,21),(54,25),(57,32),(55,38),(60,43),(53,50),(45,51),(39,57),(30,56),(24,58),(17,53),(10,53),(7,45),(3,40)],
      [(4,28),(10,22),(16,21),(19,12),(26,9),(33,13),(38,9),(45,12),(48,19),(54,23),(56,31),(61,37),(57,45),(49,47),(43,53),(32,57),(25,54),(17,56),(10,50),(8,41),(3,36)],
      [(3,32),(9,26),(13,17),(22,15),(27,8),(34,9),(39,15),(46,14),(51,23),(50,29),(58,33),(60,41),(54,48),(46,49),(42,56),(32,58),(26,53),(18,55),(11,48),(10,42),(4,40)],
      [(4,25),(12,21),(16,15),(24,17),(29,8),(37,9),(42,16),(49,18),(50,26),(58,29),(60,37),(55,42),(56,49),(46,54),(38,52),(32,57),(25,57),(19,51),(10,49),(7,41),(3,35)],
    ]
    d.polygon(shapes[variant],fill=deep,outline=outline)
    px,py=[(29,25),(33,28),(28,29),(34,25)][variant]
    # Crumpled rock plates radiate *around* the summit; no frontal triangular icon.
    d.polygon([(8,31),(13,23),(21,20),(24,13),(29,11),(34,17),(px,py),(25,31),(20,35),(13,40),(7,38)],fill=base)
    d.polygon([(15,26),(22,23),(26,17),(30,16),(px,py),(24,29),(21,32),(15,33)],fill=light)
    d.polygon([(px,py),(35,18),(41,13),(45,17),(46,23),(52,28),(51,33),(43,35),(39,30)],fill=shadow)
    d.polygon([(px,py),(36,28),(41,34),(47,37),(51,43),(47,48),(39,47),(33,42),(29,36)],fill=base)
    d.polygon([(px,py),(29,34),(23,40),(24,46),(29,51),(36,52),(35,55),(26,53),(21,50),(17,50),(12,46),(12,42),(20,36)],fill=shadow)
    d.polygon([(px-1,py+2),(27,34),(22,38),(20,44),(16,45),(16,41),(21,34)],fill=light)
    d.polygon([(px+2,py+2),(35,33),(36,38),(42,43),(42,47),(36,44),(32,38)],fill=light)
    # Stepped terrace caps and matching shadow lips give rock volume at 1x zoom.
    ledges=[(11,30,6),(16,25,5),(23,20,4),(27,15,3),(9,37,6),(16,39,4),
            (24,32,4),(22,43,4),(28,48,5),(35,48,4),(42,43,5),(47,37,4),
            (39,31,5),(39,21,3),(45,26,4),(15,47,4),(46,48,5)]
    for i,(x,y,n) in enumerate(ledges):
        if variant%2 and i%3==0:x+=2;y+=1
        d.line((x,y,x+n,y),fill=light if i%3 else shine)
        d.line((x+1,y+1,x+n-1,y+1),fill=shadow)
        if i%2==0:d.line((x+n,y+1,x+n,y+3),fill=deep)
    d.line([(px-3,py),(px,py-4),(px+2,py-3),(px+2,py)],fill=shine)
    d.line([(px+3,py),(px+5,py+5),(px+4,py+9),(px+7,py+13)],fill=deep)
    d.line([(px-1,py+4),(px-4,py+8),(px-4,py+10)],fill=shadow)
    d.line([(34,18),(37,15),(40,15)],fill=light)
    d.line([(13,49),(18,51),(22,51)],fill=shadow)
    d.line([(46,52),(51,49),(54,45)],fill=outline)
    # Small joined chips, sparse enough to keep the rock readable.
    rng=random.Random(91+variant)
    valid=[tuple(bytes.fromhex(c[1:])) for c in (base,light)]
    for i in range(24):
        x,y=rng.randrange(10,52),rng.randrange(18,50)
        if im.getpixel((x,y))[:3] in valid:
            d.line((x,y,x+1,y),fill=shine if i%5==0 else shadow)
    return im


def corner_mask(bits):
    # Marching-square masks use 2px steps at corners; a full tile remains exactly 32px.
    yy,xx=np.mgrid[0:16,0:16];x=(xx+.5)/16;y=(yy+.5)/16
    nw,ne,sw,se=[int(bool(bits&(1<<n))) for n in range(4)]
    value=nw*(1-x)*(1-y)+ne*x*(1-y)+sw*(1-x)*y+se*x*y
    return Image.fromarray((value>=.5).astype(np.uint8)*255).resize((32,32),Image.Resampling.NEAREST)


def render_tiles(reference, outdir):
    """Convert the semantic plan to a reusable corner-connected grid and bake its pixels."""
    w,h=reference.size;cols,rows=w//TILE,h//TILE
    source=np.array(reference)
    nodes=source[np.minimum(np.arange(rows+1)*TILE,h-1)[:,None],np.minimum(np.arange(cols+1)*TILE,w-1)[None,:]]
    textures=[[ground(k,v) for v in range(8)] for k in range(5)]
    masks=[corner_mask(b) for b in range(16)]
    im=Image.new('RGB',(w,h));semantic=Image.new('L',(w,h))
    ids=[];rng=random.Random(2671)
    for cy in range(rows):
        row=[]
        for cx in range(cols):
            corners=[int(nodes[cy,cx]),int(nodes[cy,cx+1]),int(nodes[cy+1,cx]),int(nodes[cy+1,cx+1])]
            variant=rng.randrange(8);tile=textures[0][variant].copy();types=Image.new('L',(32,32))
            bits_by_kind=[]
            # Plan precedence: mountain crossings are retained, not flooded by a new river.
            for kind in [1,2,4,3]:
                bits=sum(1<<i for i,c in enumerate(corners) if c==kind)
                bits_by_kind.append(bits)
                if bits:
                    tile.paste(textures[kind][variant],(0,0),masks[bits]);types.paste(kind,(0,0,32,32),masks[bits])
            im.paste(tile,(cx*32,cy*32));semantic.paste(types,(cx*32,cy*32))
            row.append([variant]+bits_by_kind)
        ids.append(row)
    kind=np.array(semantic)
    # Shore bands and forest margins follow the *same* grid mask. No blurred gradients.
    pixels=np.array(im)
    def grow(mask,n):return np.array(Image.fromarray(mask.astype(np.uint8)*255).filter(ImageFilter.MaxFilter(n)))>0
    wet=kind==4
    coast=grow(~wet,9)&wet; foam=grow(~wet,3)&wet
    pixels[coast]=[72,123,131];pixels[foam]=[129,163,154]
    bank=grow(wet,5)&~wet&(kind!=3)
    pixels[bank&(kind!=1)]=[117,112,77];pixels[bank&(kind==1)]=[175,196,190]
    forest=kind==2
    pixels[grow(~forest,5)&forest]=[70,103,56]
    mountains=kind==3
    pixels[grow(~mountains,5)&mountains]=[77,88,59]
    snow=kind==1
    pixels[grow(~snow,3)&snow&~bank]=[181,200,183]
    im=Image.fromarray(pixels)
    # Ridge decorations stay on a 32px lattice, using 64px (2x2) native metatiles.
    rock_textures=[[mountain(v,snow) for v in range(4)] for snow in [False,True]]
    rock_proofs=[]
    for cy in range(0,rows-1):
        for cx in range(0,cols-1):
            x,y=cx*TILE,cy*TILE
            if kind[y+32,x+32]!=3:continue
            if cy%2 != cx%2:continue
            if not np.any(kind[y:y+64,x:x+64]==3):continue
            v=((cx*17)^(cy*31)^(cx//2))%4;snow=int(y<h*.10)
            sprite=rock_textures[snow][v].copy()
            alpha=np.array(sprite.getchannel('A'))
            # Like trees, ridge silhouettes may overhang the tile border; never slice
            # a summit flat at the biome edge or put a rock over planned water.
            if np.any((alpha>0)&(kind[y:y+64,x:x+64]==4)):continue
            im.paste(sprite,(x,y),sprite)
            rock_proofs.append([cx,cy,snow,v])
    outdir.mkdir(parents=True,exist_ok=True)
    atlas=Image.new('RGB',(8*TILE,5*TILE))
    for k in range(5):
        for v in range(8):atlas.paste(textures[k][v],(v*TILE,k*TILE))
    atlas.save(outdir/'ground-tiles.png')
    transitions=Image.new('L',(16*TILE,TILE))
    for b,mask in enumerate(masks):transitions.paste(mask,(b*TILE,0))
    transitions.save(outdir/'corner-masks.png')
    rocks=Image.new('RGBA',(4*64,2*64))
    for snow in range(2):
        for v in range(4):rocks.paste(rock_textures[snow][v],(v*64,snow*64))
    rocks.save(outdir/'mountain-tiles.png')
    (outdir/'tile-grid.json').write_text(json.dumps({'tile_size':TILE,'size':[cols,rows],'cell_format':['variation','snow_mask','forest_mask','water_mask','mountain_mask'],'cells':ids,'mountains':rock_proofs},separators=(',',':'))+'\n')
    return im,semantic,{'tile_size':TILE,'grid_size':[cols,rows],'ground_variants':8,'mountain_metatile_size':64,'mountain_count':len(rock_proofs)}
