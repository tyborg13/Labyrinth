import sys; sys.path.insert(0, sys.argv[1])
from iso import poly, tile, BASE_CSS, ICONS
CX, CY, W, H = 992.5, 237.3, 130.2, 65.1
G = "file:///Users/borgerding/workspace/Labyrinth.worktrees/peer-benchmark/assets/art/icons/guardians/"
ice = [(3,1),(3,2),(3,3)]
polys = [poly(CX, CY, W, H, i, j, "ice") for i, j in ice]
polys.append(poly(CX, CY, W, H, 3, 0, "ice"))
polys.append(poly(CX, CY, W, H, 3, 0, "mark", 0.7))
x0, y0, _ = tile(CX, CY, W, H, 3, 3); x1, y1, _ = tile(CX, CY, W, H, 3, 0)
arc = f'<path class="leap" d="M{x0:.0f},{y0-30:.0f} Q{(x0+x1)/2:.0f},{min(y0,y1)-150:.0f} {x1:.0f},{y1-10:.0f}"/>'
html = f"""<!doctype html><html><head><meta charset="utf-8"><style>{BASE_CSS}
.ice {{ fill: rgba(150,215,255,.20); stroke: #a9e2ff; stroke-width: 2.2; stroke-dasharray: 6 4; }}
.mark {{ fill: rgba(199,69,59,.34); stroke: #ff6a5c; stroke-width: 3; }}
.leap {{ fill: none; stroke: #ff6a5c; stroke-width: 3; stroke-dasharray: 10 7; opacity: .85; }}
.gbar {{ position:absolute; left:640px; top:14px; width:640px; display:flex; flex-direction:column; align-items:center; gap:6px; }}
.gbar .name {{ font:30px/1 CrumbleDisplay; color:#f6ead2; text-shadow:0 2px 3px #000; display:flex; align-items:center; gap:10px; }}
.gbar .name img {{ width:30px; height:30px; }}
.gbar .hp {{ width:560px; height:20px; border:2px solid #7a5a32; border-radius:11px; background:#1a0c0e; box-shadow: inset 0 0 0 1px #000, 0 2px 6px #000a; position:relative; overflow:hidden; }}
.gbar .hp i {{ position:absolute; inset:0; background:linear-gradient(#d0646a,#9a3a41); }}
.gbar .hp span {{ position:absolute; inset:0; text-align:center; font:600 14px/20px CrumbleUI; color:#fff; text-shadow:0 1px 2px #000; }}
.gbar .row {{ display:flex; gap:8px; align-items:center; font:600 13px/1 CrumbleUI; color:#d9cbb0; }}
.badge {{ display:flex; align-items:center; gap:6px; padding:3px 11px 3px 4px; border-radius:12px; background:#0e1720e8; border:1.5px solid #8fd3ff; color:#d8f1ff; letter-spacing:.12em; }}
.badge img, .c img {{ width:18px; height:18px; }}
.row em {{ font-style:normal; letter-spacing:.14em; color:#9b8d75; margin-left:10px; }}
.c {{ display:flex; align-items:center; gap:5px; padding:3px 9px 3px 4px; background:#120b07d9; border:1px solid #5a4228; border-radius:12px; }}
.c.now {{ border-color:#ff6a5c; color:#ffd0c8; box-shadow:0 0 8px #d9534a66; }}
.chip {{ position:absolute; display:flex; flex-direction:column; align-items:center; }}
.chip .cap {{ font:26px/1 CrumbleDisplay; color:#fff2d6; text-shadow:0 2px 3px #000, 0 0 8px #000; margin-bottom:4px; }}
.chip .pill {{ display:flex; align-items:center; gap:8px; padding:4px 12px 4px 5px; background:#160d0bee; border:2px solid #ff6a5c; border-radius:18px; font:600 20px/1 CrumbleUI; color:#fff; }}
.chip .pill img {{ width:24px; height:24px; }} .chip .pill small {{ font-size:13px; color:#f0b85a; letter-spacing:.06em; }}
</style></head><body><div class="stage">
<img class="bg" src="rimejaw_encounter.png">
<svg class="ov" width="1920" height="1080">{''.join(polys)}{arc}</svg>
<div class="gbar"><div class="name"><img src="{G}guardian_category.png">Rimejaw</div>
  <div class="hp"><i></i><span>48 / 48</span></div>
  <div class="row"><div class="badge"><img src="{ICONS}targeting.png">THE HUNT</div><em>NEXT</em>
    <div class="c now"><img src="{ICONS}dive.png">Harrowing Pounce</div>
    <div class="c"><img src="{ICONS}melee.png">Frostbite</div>
    <div class="c"><img src="{ICONS}surface_ice.png">Rime Trail</div></div></div>
<div class="chip" style="left:1255px;top:{y1+18:.0f}px"><div class="cap">Harrowing Pounce</div>
  <div class="pill"><img src="{ICONS}dive.png">7 <small>LANDS NEXT TURN</small></div></div>
<div class="callout" style="left:44px;top:360px;width:420px;padding:16px 20px 14px">
  <div class="eyebrow">Rimejaw · the Hunt</div>
  <h4>Marked prey</h4>
  <p>Rimejaw marks the tile it will pounce on, one turn ahead. Its trail is Ice.</p>
  <p>Make it land on its own Ice: it lands Chilled, and an Ice attack Freezes it.</p>
  <div class="foot">ANY KEY TO CONTINUE</div></div>
</div></body></html>"""
open(sys.argv[2], "w").write(html)
