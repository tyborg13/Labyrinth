"""Original miniature ornaments: shaded vectors, curved forms and soft light.

The same polygons and color stops produce outlined SVG art and the PNG render.
All drawing stays in the approved left ornament well; typography/frame live in
render-banners.py. No external image, stock icon, or font is used here.
"""
import math
from PIL import Image, ImageDraw

AA = 3


def rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def shade(art, pts, top, bottom, stroke=None, width=1, horizontal=False):
    """Clipped material gradient, identical user-space stops in both outputs."""
    x0, y0 = math.floor(min(x for x, y in pts)), math.floor(min(y for x, y in pts))
    x1, y1 = math.ceil(max(x for x, y in pts)), math.ceil(max(y for x, y in pts))
    w, h = max(1, (x1-x0)*AA), max(1, (y1-y0)*AA)
    mask = Image.new('L', (w, h))
    md = ImageDraw.Draw(mask)
    md.polygon([((x-x0)*AA, (y-y0)*AA) for x, y in pts], fill=255)
    layer = Image.new('RGBA', (w, h))
    ld = ImageDraw.Draw(layer)
    a, b = rgb(top), rgb(bottom)
    count = w if horizontal else h
    for i in range(count):
        t = i / max(1, count-1)
        color = tuple(round(a[j]*(1-t)+b[j]*t) for j in range(3)) + (255,)
        ld.line([(i, 0), (i, h)] if horizontal else [(0, i), (w, i)], fill=color)
    layer.putalpha(mask)
    art.image.alpha_composite(layer, (x0*AA, y0*AA))
    identifier = 'material-' + str(len(art.parts))
    dx, dy = (x1, y0) if horizontal else (x0, y1)
    art.parts.append(f'<defs><linearGradient id="{identifier}" gradientUnits="userSpaceOnUse" x1="{x0}" y1="{y0}" x2="{dx}" y2="{dy}"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs>')
    coords = ' '.join(f'{x:.3f},{y:.3f}' for x, y in pts)
    art.parts.append(f'<polygon points="{coords}" fill="url(#{identifier})"/>')
    if stroke:
        art.line(pts + pts[:1], stroke, width)


def glow(art, x, y, rx, ry, color, opacity):
    """Smooth finite radial falloff instead of diagrammatic radial dashes."""
    x0, y0 = math.floor(x-rx), math.floor(y-ry)
    w, h = math.ceil(rx*2*AA), math.ceil(ry*2*AA)
    layer = Image.new('RGBA', (w, h))
    pixels = layer.load()
    base = rgb(color)
    for py in range(h):
        for px in range(w):
            r = math.sqrt(((x0+px/AA-x)/rx)**2 + ((y0+py/AA-y)/ry)**2)
            alpha = round(255*opacity*max(0, 1-r)**2)
            if alpha:
                pixels[px, py] = base + (alpha,)
    art.image.alpha_composite(layer, (x0*AA, y0*AA))
    identifier = 'light-' + str(len(art.parts))
    stops = ''.join(f'<stop offset="{i/8}" stop-color="{color}" stop-opacity="{opacity*(1-i/8)**2:.5f}"/>' for i in range(9))
    art.parts.append(f'<defs><radialGradient id="{identifier}">{stops}</radialGradient></defs><ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="url(#{identifier})"/>')


def ellipse(x, y, rx, ry, count=56):
    return [(x+rx*math.cos(i*2*math.pi/count), y+ry*math.sin(i*2*math.pi/count)) for i in range(count)]


def bezier(start, *segments):
    pts = [start]
    for c1, c2, end in segments:
        p = pts[-1]
        for n in range(1, 19):
            t = n/18
            pts.append(tuple((1-t)**3*p[j]+3*(1-t)**2*t*c1[j]+3*(1-t)*t*t*c2[j]+t**3*end[j] for j in (0, 1)))
    return pts


def diamond(x, y, w, h):
    return [(x, y-h), (x+w, y), (x, y+h), (x-w, y)]


def tile(art, x, y, active=False):
    w, h, depth = 25, 12, 5
    art.poly([(x-w,y),(x,y+h),(x,y+h+depth),(x-w,y+depth)], '#493b34' if active else '#302d30')
    art.poly([(x,y+h),(x+w,y),(x+w,y+depth),(x,y+h+depth)], '#211e24')
    shade(art, diamond(x,y,w,h), '#c2aa7b' if active else '#89817c', '#76563c' if active else '#49434a', '#28252a', .8)
    shade(art, diamond(x,y,w-3,h-2), '#997b4e' if active else '#6f6969', '#624632' if active else '#433e47')
    art.line([(x-w+1,y),(x,y-h+1),(x+w-1,y)], '#d6bc83' if active else '#a2978a', 1)
    art.line([(x-w+5,y+1),(x-w+11,y+4),(x-w+9,y+6)], '#55483d' if active else '#353039', .8)


def pawn(art, x, y, purple=False):
    glow(art,x,y+11,13,6,'#090a10',.9)
    shade(art,ellipse(x,y+8,10,4),'#aa95ba' if purple else '#ddc695','#463749' if purple else '#67513a')
    pts=bezier((x-7,y+7),((x-5,y+3),(x-3,y+1),(x-3,y-4)),((x+2,y-7),(x+5,y-1),(x+4,y+2)),((x+5,y+5),(x+8,y+6),(x+7,y+8)))
    shade(art,pts,'#b7a0c8' if purple else '#dfc38a','#594469' if purple else '#82623e')
    shade(art,ellipse(x,y-5,5.6,6),'#e4d6ee' if purple else '#f3ddb0','#756280' if purple else '#947345',horizontal=True)
    art.line([(x-3,y-8),(x-4,y-5)],'#f1e4c9',.9)


def board(art):
    glow(art,99,102,65,43,'#0a0910',.85)
    for x,y,active in [(81,64,False),(116,82,False),(46,82,False),(81,100,True),(116,118,False)]:
        tile(art,x,y,active)
    # The warm inset and two physical pieces suggest a positional choice.
    path=[(48,87),(81,105),(114,88)]
    art.line(path,'#302423',3.8)
    art.line(path,'#d4b16c',1.7)
    art.poly([(108,87),(118,85),(114,94)],'#e6c78c')
    pawn(art,47,71)
    pawn(art,117,70,True)
    art.circle(82,104,2,'#f5d89a')


def gear(art):
    glow(art,96,100,66,46,'#090910',.9)
    cards=[([(45,61),(84,52),(102,118),(60,130)],'#716457','#29242c'),
           ([(65,48),(110,48),(110,125),(65,125)],'#b59b70','#594538'),
           ([(91,48),(140,61),(121,133),(74,120)],'#cab28a','#76604a')]
    for pts,a,b in cards:
        art.poly([(x+2,y+3) for x,y in pts],'#101016')
        shade(art,pts,a,b,'#ddc08a',1)
        cx=sum(x for x,y in pts)/4; cy=sum(y for x,y in pts)/4
        inset=[(cx+(x-cx)*.82,cy+(y-cy)*.88) for x,y in pts]
        shade(art,inset,'#403340','#201d29','#806a55',.8)
        art.poly(diamond(cx,cy,8,14),'#64516c','#a792ad',.7)
        art.poly(diamond(cx-1,cy-2,4,8),'#bc9d77')
    # Forged blade: cool fuller, bright edge and a curved brass guard.
    blade=[(79,109),(124,46),(137,34),(132,52),(91,117)]
    art.poly([(x+3,y+2) for x,y in blade],'#16131c')
    shade(art,blade,'#e3dfd1','#736c7f','#cfcbc0',.9)
    shade(art,[(85,108),(131,44),(89,114)],'#a8aabb','#4c4d66')
    art.line([(80,108),(133,39)],'#f4ead5',1.2)
    guard=bezier((73,103),((81,100),(96,115),(100,117)),((99,121),(94,122),(93,118)),((85,112),(77,108),(74,107)))
    shade(art,guard,'#efcf8c','#78542d','#bfa06b',.7)
    shade(art,[(81,111),(88,116),(77,132),(70,127)],'#78604f','#34282b','#b38e59',.7)
    for x,y in [(78,118),(75,122),(73,126)]:
        art.line([(x,y),(x+5,y+3)],'#c7a26c',1)
    shade(art,diamond(71,131,6,6),'#e7c78a','#76562e','#d0af77',.8)


def light(art):
    # Amber light meets the violet well without thin radial tick marks.
    glow(art,98,95,66,59,'#705c9b',.55)
    glow(art,97,99,49,45,'#c68632',.66)
    glow(art,100,128,37,10,'#0a0810',.8)
    shade(art,ellipse(98,42,9,11),'#c4aa79','#504039')
    shade(art,ellipse(98,42,6,8),'#211c25','#37303c')
    art.line(bezier((93,39),((92,34),(99,31),(102,37))),'#eccea0',1.1)
    shade(art,[(94,51),(102,51),(104,61),(92,61)],'#e0bd81','#786044')
    cap=bezier((75,72),((81,69),(83,56),(96,57)),((108,56),(111,64),(118,72)),((108,78),(83,78),(75,72)))
    shade(art,cap,'#c8a774','#5b4437','#d0b180',.9)
    art.line(bezier((81,69),((89,65),(106,64),(112,71))),'#e1c090',1.3)
    shade(art,[(78,77),(114,77),(110,118),(83,121)],'#5a452f','#b37b37','#372934',1)
    shade(art,[(82,80),(96,80),(96,117),(86,116)],'#9f7944','#e3b258')
    shade(art,[(98,80),(111,78),(107,116),(98,118)],'#bd9149','#755033')
    glow(art,96,100,16,23,'#fbd491',.95)
    flame=bezier((97,83),((102,94),(90,92),(103,99)),((108,106),(101,114),(94,111)),((85,107),(92,100),(90,96)),((95,98),(96,90),(97,83)))
    shade(art,flame,'#fff4c8','#f0b34f')
    core=bezier((97,96),((98,102),(94,103),(97,108)),((103,109),(99,102),(97,96)))
    shade(art,core,'#ffffe5','#fff0b6')
    art.line([(85,84),(85,96)],'#f4dba6',1)
    for pts in [[(77,77),(83,120),(88,119),(82,77)],[(110,77),(106,119),(112,117),(116,76)]]:
        shade(art,pts,'#e4c288','#756045','#604831',.6)
    art.line([(79,79),(85,117)],'#f1d2a0',1)
    base=bezier((79,121),((87,116),(109,116),(114,119)),((116,124),(106,127),(97,128)),((87,128),(79,126),(79,121)))
    shade(art,base,'#e0bd7b','#5e4736','#ad8d59',.7)
    shade(art,[(86,128),(108,128),(110,132),(84,132)],'#b69764','#594431')
    for x,y in [(79,75),(115,74),(83,121),(111,120)]:
        art.circle(x,y,1.2,'#f0d1a1')
    for x,y in [(59,95),(133,105),(125,60)]:
        glow(art,x,y,3,4,'#d3ab73',.44)


def route(art):
    glow(art,92,111,69,34,'#0a0910',.85)
    # Two shallow, worn causeways branch toward a warm camp and a violet arch.
    for pts in [[(97,137),(88,136),(68,112),(74,105)],[(91,126),(85,120),(124,79),(136,77)]]:
        shade(art,pts,'#8c817a','#514449','#322b35',.8)
    for x,y in [(94,130),(85,120),(103,108),(113,97),(122,87)]:
        art.line([(x-3,y-2),(x+3,y+2)],'#b2a087',.8)
    glow(art,131,73,29,37,'#735390',.52)
    # Weathered arch: a dark recess and bevelled keystone, not a map diamond.
    arch=bezier((117,88),((116,70),(113,49),(130,42)),((147,43),(148,64),(147,84)))
    shade(art,arch,'#9b849f','#54415c','#312637',1)
    inner=bezier((123,85),((121,70),(121,54),(131,52)),((140,55),(140,70),(141,84)))
    shade(art,inner,'#171322','#39213f')
    art.line(bezier((122,61),((124,53),(127,49),(131,48))),'#c7b5c8',1.1)
    for pts in [[(118,63),(124,63)],[(117,74),(122,73)],[(138,61),(145,61)],[(141,73),(147,73)]]:
        art.line(pts,'#322837',1)
    shade(art,[(126,42),(134,42),(134,50),(128,51)],'#b9a5b0','#77627d','#65516a',.7)
    shade(art,diamond(131,85,16,5),'#94808b','#4a3b51')
    # Ash bed, rounded stones, crossed split logs, and a curved two-tone flame.
    glow(art,66,95,39,40,'#d58e38',.53)
    shade(art,ellipse(65,116,24,9),'#635047','#2b262c')
    for x,y,r in [(46,114,5),(52,121,5),(63,124,5),(75,122,5),(84,116,5)]:
        shade(art,ellipse(x,y,r,3.5),'#a2917d','#4b4142')
    for pts in [[(45,109),(48,104),(84,118),(80,123)],[(47,118),(80,104),(84,109),(50,123)]]:
        shade(art,pts,'#ae7844','#50362e','#342630',.7)
    art.line([(50,107),(77,118)],'#d4a163',1)
    art.line([(52,119),(80,108)],'#e6ba76',1)
    fire=bezier((68,66),((70,79),(58,80),(66,89)),((72,91),(75,81),(76,80)),((86,94),(78,109),(67,114)),((55,114),(46,106),(51,94)),((55,99),(61,97),(57,89)),((53,82),(62,77),(68,66)))
    shade(art,fire,'#e7ae60','#bb6535')
    inner=bezier((67,87),((73,98),(69,97),(74,101)),((73,109),(65,114),(60,108)),((55,102),(63,95),(67,87)))
    shade(art,inner,'#fff1b7','#efbd70')
    glow(art,64,108,11,9,'#fff0b7',.5)
    art.circle(93,132,3,'#d1b581','#ead9b5',.7)
    for x,y in [(60,68),(75,61),(50,80)]:
        glow(art,x,y,2,3,'#e7b66e',.6)
