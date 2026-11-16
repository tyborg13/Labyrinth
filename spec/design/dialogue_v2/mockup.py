import sys, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
R="/Users/borgerding/workspace/Labyrinth.worktrees/release/"
SP="/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/"
def hexc(h,a=255): h=h.lstrip('#'); return (int(h[0:2],16),int(h[2:4],16),int(h[4:6],16),a)
INK0,INK1,INK2,INK3=hexc("0b0908"),hexc("15110e"),hexc("1f1813"),hexc("2a2119")
GOLD_DIM,GOLD,GOLD_B,EMBER,TEXT,TEXT2,TEXT3=hexc("7c6240"),hexc("c9a25e"),hexc("f0cf8a"),hexc("e8893a"),hexc("efe3c8"),hexc("b5a58a"),hexc("7f7262")
UI=R+"fonts/LabyrinthCrumble-UI.ttf"; TX=R+"fonts/LabyrinthCrumble-Text.ttf"
variant=sys.argv[1] if len(sys.argv)>1 else "line"
bg=Image.open(SP+"dlg_base/awakening_intro.png").convert("RGBA")
W,H=bg.size
fill=bg.crop((425,840,1495,905)).resize((1070,230)); bg.paste(fill,(425,845))
# 1. bottom seat scrim (replaces the flat full-screen 0.18 scrim)
scr=Image.new("RGBA",(W,H),(0,0,0,0)); d=ImageDraw.Draw(scr)
for y in range(620,H):
    t=(y-620)/(H-620); a=int(255*0.80*(t**1.6)); d.line([(0,y),(W,y)],fill=INK0[:3]+(a,))
img=Image.alpha_composite(bg,scr)
# panel geometry
PX,PW=328,1264; PH=156 if variant=="line" else 214; PY=H-36-PH
# 2. soft drop shadow
sh=Image.new("RGBA",(W,H),(0,0,0,0)); ImageDraw.Draw(sh).rounded_rectangle([PX-6,PY-2,PX+PW+6,PY+PH+14],8,fill=(0,0,0,170))
img=Image.alpha_composite(img,sh.filter(ImageFilter.GaussianBlur(14)))
# 3. ink glass fill: vertical gradient INK2 -> INK0, 0.95, plus a warm inner glow at the top edge
pan=Image.new("RGBA",(PW,PH),(0,0,0,0)); pd=ImageDraw.Draw(pan)
for y in range(PH):
    t=y/(PH-1); c=[int(INK2[i]*(1-t)+INK0[i]*t) for i in range(3)]; pd.line([(0,y),(PW,y)],fill=tuple(c)+(244,))
glow=Image.new("RGBA",(PW,PH),(0,0,0,0)); gd=ImageDraw.Draw(glow)
gd.ellipse([PW*0.18,-PH*0.9,PW*0.82,PH*0.55],fill=(232,137,58,26))
pan=Image.alpha_composite(pan,glow.filter(ImageFilter.GaussianBlur(40)))
mask=Image.new("L",(PW,PH),0); ImageDraw.Draw(mask).rounded_rectangle([0,0,PW-1,PH-1],3,fill=255)
img.paste(pan,(PX,PY),Image.composite(pan,Image.new("RGBA",(PW,PH)),mask).split()[3])
d=ImageDraw.Draw(img)
# 4. gilded double hairline + bold corner brackets + diamond studs
d.rounded_rectangle([PX,PY,PX+PW-1,PY+PH-1],3,outline=GOLD_DIM,width=1)
d.rectangle([PX+5,PY+5,PX+PW-6,PY+PH-6],outline=GOLD_DIM[:3]+(110,),width=1)
L=26
for (cx,cy,sx,sy) in [(PX,PY,1,1),(PX+PW-1,PY,-1,1),(PX,PY+PH-1,1,-1),(PX+PW-1,PY+PH-1,-1,-1)]:
    d.line([(cx,cy),(cx+22*sx,cy)],fill=GOLD,width=2); d.line([(cx,cy),(cx,cy+22*sy)],fill=GOLD,width=2)
    d.polygon([(cx+3*sx,cy+3*sy-3),(cx+3*sx+3,cy+3*sy),(cx+3*sx,cy+3*sy+3),(cx+3*sx-3,cy+3*sy)],fill=GOLD_B)
for (sx,sy) in [(PX+PW//2,PY+PH-1)]:
    d.polygon([(sx,sy-5),(sx+5,sy),(sx,sy+5),(sx-5,sy)],fill=GOLD)
# 5. medallion portrait: ring 184 px, centre breaks the top edge by 44 px
RING=172; MX=PX+30; MY=PY-40
ring=Image.open(R+"assets/art/ui/visual_pass_4/medallion_ring.png").convert("RGBA").resize((RING,RING),Image.LANCZOS)
# velvet accent fill
acc=hexc("b8aa90"); vel=Image.new("RGBA",(RING,RING),(0,0,0,0)); vd=ImageDraw.Draw(vel)
for r in range(RING//2,0,-1):
    t=r/(RING/2); c=[int(acc[i]*(0.10+0.22*(1-t))) for i in range(3)]; vd.ellipse([RING/2-r,RING/2-r,RING/2+r,RING/2+r],fill=tuple(c)+(255,))
art=Image.open(R+"assets/placeholders/units/emaciated_man_anime_trial.png").convert("RGBA")
crop=art.crop((60,8,60+132,8+132)).resize((int(RING*0.86),int(RING*0.86)),Image.NEAREST)
vel.alpha_composite(crop,((RING-crop.width)//2,int(RING*0.10)))
cm=Image.new("L",(RING,RING),0); ImageDraw.Draw(cm).ellipse([RING*0.10,RING*0.10,RING*0.90,RING*0.90],fill=255)
vel.putalpha(ImageChops.multiply(vel.split()[3],cm))
shm=Image.new("RGBA",(W,H),(0,0,0,0)); ImageDraw.Draw(shm).ellipse([MX+6,MY+10,MX+RING+6,MY+RING+14],fill=(0,0,0,160))
img=Image.alpha_composite(img,shm.filter(ImageFilter.GaussianBlur(10)))
img.alpha_composite(vel,(MX,MY)); img.alpha_composite(ring,(MX,MY))
d=ImageDraw.Draw(img)
# 6. nameplate: bronze dry-brush stroke over the top edge
TXX=MX+RING+28
br=Image.open(R+"assets/art/ui/turn_order_ink/brush_a.png").convert("RGBA").resize((300,58),Image.LANCZOS)
tint=Image.new("RGBA",br.size,hexc("6b5232")[:3]+(255,)); tint.putalpha(ImageChops.multiply(br.split()[3],Image.new("L",br.size,232)))
img.alpha_composite(tint,(TXX-24,PY-29))
d=ImageDraw.Draw(img)
fname=ImageFont.truetype(UI,20)
name="EMACIATED MAN"; x=TXX
for ch in name:
    d.text((x,PY+7),ch,font=fname,fill=GOLD_B,stroke_width=3,stroke_fill=hexc("0a0706"),anchor="ls"); x+=fname.getlength(ch)+3.5
# 7. body text: Crumble Text 25 px, TEXT, 8 px leading
fb=ImageFont.truetype(TX,25)
lines=["A dragon has fallen. I felt it... and so did the Moltshard you carried away."] if variant=="line" else ["The Moltshard hums with what it took. Give it to me, and I can wake","what sleeps in you."]
y=PY+44
for ln in lines:
    d.text((TXX,y),ln,font=fb,fill=TEXT,anchor="la"); y+=25+10
# 8. continue cue or choices
fc=ImageFont.truetype(UI,14)
if variant=="line":
    hint="CLICK TO CONTINUE"; hx=PX+PW-30; hy=PY+PH-26
    # ember diamond with halo, hint left of it
    halo=Image.new("RGBA",(W,H),(0,0,0,0)); ImageDraw.Draw(halo).ellipse([hx-14,hy-14,hx+14,hy+14],fill=EMBER[:3]+(90,))
    img=Image.alpha_composite(img,halo.filter(ImageFilter.GaussianBlur(6))); d=ImageDraw.Draw(img)
    d.polygon([(hx,hy-7),(hx+7,hy),(hx,hy+7),(hx-7,hy)],fill=EMBER)
    tx=hx-20; w=sum(fc.getlength(c)+3 for c in hint)-3; x=tx-w
    for ch in hint: d.text((x,hy),ch,font=fc,fill=TEXT2,anchor="lm"); x+=fc.getlength(ch)+3
else:
    # two choice plates bottom-right: quiet ink plate + primary ember plate
    def plate(x0,y0,w,h,label,primary):
        global img
        if primary:
            hl=Image.new("RGBA",(W,H),(0,0,0,0)); ImageDraw.Draw(hl).rounded_rectangle([x0-6,y0-6,x0+w+6,y0+h+6],6,fill=EMBER[:3]+(70,))
            img=Image.alpha_composite(img,hl.filter(ImageFilter.GaussianBlur(8)))
        dd=ImageDraw.Draw(img)
        top=hexc("8a4a1c") if primary else INK3; bot=hexc("4e2810") if primary else INK1
        for yy in range(h):
            t=yy/(h-1); c=[int(top[i]*(1-t)+bot[i]*t) for i in range(3)]; dd.line([(x0,y0+yy),(x0+w,y0+yy)],fill=tuple(c)+(255,))
        dd.rectangle([x0,y0,x0+w,y0+h],outline=GOLD if primary else GOLD_DIM,width=1)
        dd.rectangle([x0+3,y0+3,x0+w-3,y0+h-3],outline=(GOLD_B if primary else GOLD_DIM)[:3]+(90,),width=1)
        f=ImageFont.truetype(UI,18); lw=sum(f.getlength(c)+2 for c in label)-2; xx=x0+(w-lw)/2
        for ch in label: dd.text((xx,y0+h/2),ch,font=f,fill=GOLD_B if primary else TEXT,anchor="lm",stroke_width=2,stroke_fill=hexc("0a0706")); xx+=f.getlength(ch)+2
    plate(PX+PW-34-250,PY+PH-28-50,250,50,"Awaken · 1 Moltshard",True)
    plate(PX+PW-34-250-16-170,PY+PH-28-50,170,50,"Not yet",False)
img.convert("RGB").save(SP+"dlg_mock_%s.png"%variant)
print("ok",PX,PY,PW,PH)
