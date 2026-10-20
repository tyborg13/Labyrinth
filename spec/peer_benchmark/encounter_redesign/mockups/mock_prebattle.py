import sys; sys.path.insert(0, sys.argv[1])
from iso import BASE_CSS, ICONS
rows = [("stoneskin", "Crag Armour", "Takes half damage while touching an outcrop."),
        ("terrain_burst", "Groundsplit", "Each outcrop bursts for 7 around it. Break them (3 HP) to defuse it."),
        ("raise_terrain", "At half health", "Fury: raises three outcrops at a time.")]
body = "".join(f'<div class="r"><img src="{ICONS}{i}.png"><b>{n}</b><span>{t}</span></div>' for i, n, t in rows)
html = f"""<!doctype html><html><head><meta charset="utf-8"><style>{BASE_CSS}
.how {{ position:absolute; left:425px; top:636px; width:640px; }}
.how .h {{ display:flex; align-items:center; gap:12px; font:600 15px/1 CrumbleUI; letter-spacing:.2em; color:#d9a94e; }}
.how .h::after {{ content:""; flex:1; height:1.5px; background:linear-gradient(90deg,#9c7438,#9c743800); }}
.how .r {{ display:grid; grid-template-columns:26px 136px 1fr; gap:10px; align-items:center; margin-top:8px; font:16px/1.25 CrumbleText; color:#e6dac2; }}
.how .r img {{ width:26px; height:26px; }}
.how .r b {{ font:600 16px/1.2 CrumbleUI; color:#f3e3bf; }}
.hidebar {{ position:absolute; left:425px; top:690px; width:640px; height:116px; background:#1b1612; }}
</style></head><body><div class="stage">
<img class="bg" src="craghide_pre_battle_shift.png">
<div class="how"><div class="h">HOW IT FIGHTS</div>{body}</div>
</div></body></html>"""
open(sys.argv[2], "w").write(html)
