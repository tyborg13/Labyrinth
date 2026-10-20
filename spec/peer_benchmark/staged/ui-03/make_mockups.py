"""Empower redesign mockup on a real 1920x1080 capture: the card's own seal, charged glow, no floating chip."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
import numpy as np
P='/Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/'
S='/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/empower/'
base=Image.open('/Users/borgerding/workspace/Labyrinth/output/card-pool-overhaul-merge-2026-10-01/card_keywords_visual_probe/empower_on_stagger_preview.png').convert('RGBA')
ring=Image.open(P+'assets/art/ui/visual_pass_4/medallion_ring.png').convert('RGBA')
emp=Image.open(P+'assets/art/icons/empower.png').convert('RGBA')
tim=Image.open(P+'assets/art/icons/time.png').convert('RGBA')
hp=Image.open(P+'assets/art/icons/health_cost.png').convert('RGBA')
font=ImageFont.truetype(P+'fonts/LabyrinthCrumble-UI.ttf',20)
small=ImageFont.truetype(P+'fonts/LabyrinthCrumble-UI.ttf',16)
def bbox_alpha(im):
    return im.getbbox()
def remove_chip(im):
    a=im.copy(); patch=a.crop((1525,622,1710,662)); a.paste(patch,(1525,664)); return a
def tint(im,mul):
    arr=np.asarray(im).astype(float); arr[...,:3]=np.clip(arr[...,:3]*np.array(mul),0,255); return Image.fromarray(arr.astype(np.uint8))
def grey(im,k=0.55):
    arr=np.asarray(im).astype(float); g=arr[...,:3].mean(2,keepdims=True); arr[...,:3]=g*k+arr[...,:3]*(1-k)*0.5; return Image.fromarray(arr.astype(np.uint8))
def seal(state, d=58):
    """state: off | hover | on | blocked"""
    lay=Image.new('RGBA',(d*3,d*3),(0,0,0,0)); c=d*1.5
    if state=='on':
        g=Image.new('RGBA',lay.size,(0,0,0,0)); gd=ImageDraw.Draw(g)
        for r,a in ((d*0.95,40),(d*0.8,70),(d*0.66,110)):
            gd.ellipse((c-r,c-r,c+r,c+r),fill=(255,150,60,a))
        lay=Image.alpha_composite(lay,g.filter(ImageFilter.GaussianBlur(d*0.18)))
    dd=ImageDraw.Draw(lay); inner=d*0.40
    dd.ellipse((c-inner,c-inner,c+inner,c+inner),fill={'on':(70,32,14,255),'blocked':(46,18,18,255)}.get(state,(24,20,18,255)))
    r=ring.resize((d,d),Image.LANCZOS)
    r={'on':tint(r,(1.5,1.36,1.12)),'blocked':tint(r,(0.72,0.6,0.58)),'hover':tint(r,(1.25,1.18,1.06))}.get(state,r)
    lay.alpha_composite(r,(int(c-d/2),int(c-d/2)))
    ic=emp.crop(emp.getbbox()); s=int(d*0.52); ic=ic.resize((s,int(s*ic.height/ic.width)),Image.NEAREST)
    ic={'off':grey(ic,0.75),'hover':grey(ic,0.35),'blocked':grey(ic,0.9)}.get(state,ic)
    lay.alpha_composite(ic,(int(c-ic.width/2),int(c-ic.height/2)))
    if state=='blocked':
        dd.line((c-inner*0.75,c+inner*0.75,c+inner*0.75,c-inner*0.75),fill=(200,70,60,255),width=3)
    return lay
def plaque(kind, value, state):
    icon={'time':tim,'hp':hp}[kind]; ic=icon.crop(icon.getbbox()); ic=ic.resize((18,int(18*ic.height/ic.width)),Image.NEAREST)
    txt=value; w=ic.width+8+int(font.getlength(txt))+16; h=26
    lay=Image.new('RGBA',(w,h),(0,0,0,0)); d=ImageDraw.Draw(lay)
    fill={'on':(92,46,18,236),'blocked':(70,22,20,236)}.get(state,(28,24,21,230))
    edge={'on':(232,170,90,255),'blocked':(170,70,60,255)}.get(state,(150,118,78,255))
    d.rounded_rectangle((0,0,w-1,h-1),radius=7,fill=fill,outline=edge,width=2)
    lay.alpha_composite(ic,(8,(h-ic.height)//2))
    d.text((8+ic.width+5,h//2),txt,font=font,fill={'blocked':(240,170,160,255)}.get(state,(246,226,190,255)),anchor='lm')
    return lay
def card_glow(im, box, strength=1.0):
    x0,y0,x1,y1=box; g=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(g)
    for pad,a in ((14,50),(9,90),(5,140)):
        d.rounded_rectangle((x0-pad,y0-pad,x1+pad,y1+pad),radius=18,outline=(255,150,60,int(a*strength)),width=6)
    g=g.filter(ImageFilter.GaussianBlur(6))
    return Image.alpha_composite(im,g)
CARD=(690,705,898,1022)   # raised Overhead Smash in the capture
CORNER=(892,714)
def scene(state, label, show_cursor=False):
    im=remove_chip(base)
    if state=='on': im=card_glow(im,CARD)
    s=seal(state); im.alpha_composite(s,(CORNER[0]-s.width//2,CORNER[1]-s.height//2))
    p=plaque('time','+2',state); im.alpha_composite(p,(CORNER[0]-p.width//2,CORNER[1]+30))
    return im
for st in ('off','hover','on'):
    scene(st,st).convert('RGB').save(S+f'mock_{st}.png')
# crops for a sheet: the hand region at 1.5x
crops=[]
for st,cap in (('off','Offered: an unlit seal on the card'),('hover','Hover: the ring brightens'),('on','Charged: seal lit, card glows, numbers update')):
    im=Image.open(S+f'mock_{st}.png').crop((600,600,1040,1060)).resize((660,690),Image.NEAREST)
    canvas=Image.new('RGB',(660,730),(20,20,24)); canvas.paste(im,(0,40)); ImageDraw.Draw(canvas).text((14,20),cap,font=font,fill=(235,225,205),anchor='lm'); crops.append(canvas)
# blocked state demo: HP cost seal
bl=Image.new('RGB',(660,730),(20,20,24)); s=seal('blocked',88); bl.paste(s,(330-s.width//2,300-s.height//2),s); pq=plaque('hp','2',"blocked"); pq=pq.resize((pq.width*3//2,pq.height*3//2),Image.LANCZOS); bl.paste(pq,(330-pq.width//2,380),pq)
d=ImageDraw.Draw(bl); d.text((14,20),'Blocked: an HP cost you cannot survive',font=font,fill=(235,225,205),anchor='lm'); d.text((330,470),'Tooltip: "Not enough health: Empower costs 2 HP"',font=small,fill=(200,190,170),anchor='mm')
crops.append(bl)
sheet=Image.new('RGB',(660*4+30,730),(12,12,14))
for i,c in enumerate(crops): sheet.paste(c,(i*670,0))
sheet.save(S+'mock_states.png'); print('ok')
