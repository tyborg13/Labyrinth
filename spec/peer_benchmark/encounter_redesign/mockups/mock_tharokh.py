import sys; sys.path.insert(0, sys.argv[1])
from iso import poly, tile, BASE_CSS, ICONS
CX, CY, W, H = 960, 298, 131.4, 65.7
blocked = {(0,0),(6,0),(0,6),(6,6),(2,1),(3,1),(2,2),(3,2),(0,1),(1,0),(1,2)}
shelter = {(0,2),(1,1),(1,3),(2,0)}
polys = []
for i in range(7):
    for j in range(7):
        if (i,j) in blocked: continue
        polys.append(poly(CX, CY, W, H, i, j, "shelter" if (i,j) in shelter else "threat"))
pips = "".join(f'<i class="{"on" if k < 5 else ""}"></i>' for k in range(14))
html = f"""<!doctype html><html><head><meta charset="utf-8"><style>{BASE_CSS}
.hpcover {{ position:absolute; left:952px; top:66px; width:346px; height:34px; background:linear-gradient(#2a1416,#1a0c0e); border-radius:0 14px 14px 0; opacity:.96; }}
.hptext {{ position:absolute; left:860px; top:71px; width:200px; text-align:center; font:600 16px/24px CrumbleUI; color:#fff; text-shadow:0 1px 2px #000; }}
.hpbg {{ position:absolute; left:925px; top:72px; width:70px; height:22px; background:#b7484f; }}
.break {{ position:absolute; left:686px; top:113px; width:548px; height:22px; display:flex; align-items:center; gap:10px; }}
.break b {{ font:600 13px/1 CrumbleUI; letter-spacing:.16em; color:#f0b85a; text-shadow:0 1px 2px #000; }}
.break .pips {{ flex:1; display:flex; gap:3px; padding:3px; background:#120b07e6; border:1.5px solid #8a6330; border-radius:4px; }}
.break .pips i {{ flex:1; height:9px; background:#3b2a1a; border-radius:1px; }}
.break .pips i.on {{ background:linear-gradient(#ffd27a,#e08a2a); box-shadow:0 0 6px #ff9d3a; }}
.break span {{ font:600 15px/1 CrumbleUI; color:#f6e2b8; text-shadow:0 1px 2px #000; }}
.cycle {{ position:absolute; left:686px; top:140px; width:548px; display:flex; justify-content:center; gap:8px; font:600 13px/1 CrumbleUI; color:#d9cbb0; }}
.cycle em {{ font-style:normal; letter-spacing:.14em; color:#9b8d75; padding-top:5px; }}
.cycle .c {{ display:flex; align-items:center; gap:5px; padding:3px 9px 3px 4px; background:#120b07d9; border:1px solid #5a4228; border-radius:12px; }}
.cycle .c.now {{ border-color:#d9534a; color:#ffd0c8; box-shadow:0 0 8px #d9534a66; }}
.cycle img {{ width:18px; height:18px; }}
.chip {{ position:absolute; left:1040px; top:458px; display:flex; flex-direction:column; align-items:flex-start; }}
.chip .cap {{ font:28px/1 CrumbleDisplay; color:#fff2d6; text-shadow:0 2px 3px #000, 0 0 8px #000; margin:0 0 4px 6px; }}
.chip .pill {{ display:flex; align-items:center; gap:8px; padding:4px 12px 4px 5px; background:#160d0bee; border:2px solid #d9534a; border-radius:18px; font:600 21px/1 CrumbleUI; color:#fff; }}
.chip .pill img {{ width:26px; height:26px; }}
.chip .pill small {{ font-size:14px; color:#f0b85a; letter-spacing:.06em; }}
</style></head><body><div class="stage">
<img class="bg" src="04_tharokh_gimmick.png">
<svg class="ov" width="1920" height="1080">{''.join(polys)}</svg>
<div class="hpcover"></div><div class="hptext">31 / 64</div>
<div class="break"><img src="{ICONS}stagger.png" style="width:22px;height:22px"><b>BREAK</b><div class="pips">{pips}</div><span>5 / 14</span></div>
<div class="cycle"><em>NEXT</em>
  <div class="c now"><img src="{ICONS}terrain_burst.png">Worldbreak</div>
  <div class="c"><img src="{ICONS}melee.png">Worldspine Claw</div>
  <div class="c"><img src="{ICONS}surface_rubble.png">Bedrock Breath</div></div>
<div class="chip" style="left:1050px;top:432px"><div class="cap">Worldbreak</div>
  <div class="pill"><img src="{ICONS}terrain_burst.png">14 <small>NEXT TURN</small></div></div>
<div class="callout" style="left:1428px;top:566px;width:430px;padding:16px 20px 14px">
  <div class="eyebrow">Tharokh's Wrath · new</div>
  <h4>Worldbreak</h4>
  <p>Next turn, every tile that isn't beside a standing spire takes 14.</p>
  <p>Break it: deal 14 damage to Tharokh before then. It's Staggered and Exposed.</p>
  <div class="foot">SHELTER TILES ARE MARKED · ANY KEY TO CONTINUE</div></div>
<div style="position:absolute;left:273px;top:686px;width:80px;height:17px;background:#16110d"></div><div style="position:absolute;left:275px;top:685px;font:14px/18px CrumbleText;color:#d8c9ad"><b>31/64</b> HP</div>
</div></body></html>"""
open(sys.argv[2], "w").write(html)
