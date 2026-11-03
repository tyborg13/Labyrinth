"""Heirloom screen mockup (director). Writes choice.html and ceremony.html next to this file."""
import pathlib

HERE = pathlib.Path(__file__).parent
ITEMS = [
    {"id": "duelist_rapier", "name": "Duelist Rapier", "slot": "WEAPON", "rarity": "Rare", "accent": "#4b84d8",
     "spells": [("riposte_lunge", "Riposte Lunge"), ("battle_rhythm", "Parry Rhythm"), ("bodkin_arrow", "Needle Thrust")]},
    {"id": "glacial_bulwark", "name": "Glacial Bulwark", "slot": "OFFHAND", "rarity": "Epic", "accent": "#9b62d6",
     "spells": [("hoarfrost_wall", "Hoarfrost Wall"), ("cold_shoulder", "Cold Shoulder")]},
    {"id": "ironshod_sabatons", "name": "Ironshod Sabatons", "slot": "BOOTS", "rarity": "Rare", "accent": "#4b84d8",
     "spells": [("iron_wheel", "Iron Wheel"), ("headlong", "Headlong")]},
    {"id": "stormglass_orb", "name": "Stormglass Orb", "slot": "TRINKET", "rarity": "Rare", "accent": "#4b84d8",
     "spells": [("charged_orb", "Charged Orb")]},
]
CARD_W, CARD_H, GAP, TOP = 316, 512, 30, 168

CSS = """
@font-face { font-family: CrumbleUI; src: url(LabyrinthCrumble-UI.ttf); }
@font-face { font-family: CrumbleText; src: url(LabyrinthCrumble-Text.ttf); }
@font-face { font-family: CrumbleDisplay; src: url(LabyrinthCrumble-Display.ttf); }
:root { --ink0:#0b0908; --ink1:#15100c; --ink2:#1f1812; --ink3:#2a2119; --gold-dim:#7c6240; --gold:#c9a25e;
  --gold-bright:#f0cf8a; --ember:#e8893a; --text:#efe3c8; --text2:#b5a58a; --text3:#7f7262; }
* { box-sizing: border-box; margin: 0; padding: 0; }
body { width: 1920px; height: 1080px; overflow: hidden; background: #000 url(bg.png) no-repeat; position: relative; }
.header { position: absolute; left: 0; right: 0; top: 84px; text-align: center; }
.eyebrow { font: 16px CrumbleUI; letter-spacing: .32em; color: var(--gold); }
.sub { font: 21px CrumbleText; color: var(--text2); margin-top: 10px; }
.card { position: absolute; width: 316px; height: 512px; top: 168px; border-radius: 3px;
  background: linear-gradient(180deg, rgba(36,28,21,.97), rgba(17,13,10,.97));
  border: 1px solid var(--gold-dim); box-shadow: 0 10px 30px rgba(0,0,0,.6); }
.card::before { content: ""; position: absolute; inset: 7px; border: 1px solid rgba(201,162,94,.45); border-radius: 2px; }
.stud { position: absolute; width: 7px; height: 7px; background: var(--gold); transform: rotate(45deg); }
.card .tab { position: absolute; top: -15px; left: 50%; transform: translateX(-50%); padding: 5px 14px 4px;
  font: 15px CrumbleUI; letter-spacing: .24em; color: var(--gold-bright); background: var(--ink1);
  border: 1px solid var(--gold); border-radius: 5px; white-space: nowrap; }
.card h2 { font: 27px CrumbleUI; color: var(--gold-bright); text-align: center; margin-top: 36px; }
.medallion { width: 204px; height: 204px; border-radius: 50%; margin: 16px auto 0; position: relative;
  background: radial-gradient(circle at 50% 45%, #2c2219 0%, #120d0a 70%);
  box-shadow: inset 0 0 0 4px var(--ring), inset 0 0 0 6px #120d0a, 0 0 0 1px var(--gold-dim); }
.medallion img { position: absolute; left: 6px; top: 6px; width: 192px; height: 192px; image-rendering: pixelated; }
.rarity { font: 17px CrumbleText; text-align: center; margin-top: 12px; color: var(--accent); }
.rule { height: 1px; margin: 16px 28px 12px; background: linear-gradient(90deg, transparent, var(--gold-dim), transparent); }
.spells-h { font: 14px CrumbleUI; letter-spacing: .24em; color: var(--text3); text-align: center; margin-bottom: 10px; }
.spell { display: flex; align-items: center; gap: 12px; margin: 0 30px 8px; }
.spell img { width: 64px; height: 36px; border: 1px solid var(--gold-dim); object-fit: cover; }
.spell span { font: 18px CrumbleText; color: var(--text); }
.card.dim { filter: brightness(.72) saturate(.85); }
.card.focus { top: 154px; border-color: var(--gold-bright);
  box-shadow: 0 0 0 1px rgba(240,207,138,.35), 0 0 34px rgba(232,137,58,.42), 0 14px 34px rgba(0,0,0,.7); }
.card.focus::before { border-color: rgba(240,207,138,.75); }
.card.focus .medallion { box-shadow: inset 0 0 0 4px var(--ring), inset 0 0 0 6px #120d0a, 0 0 0 1px var(--gold),
  0 0 26px var(--glow); }
.btn { position: absolute; left: 50%; transform: translateX(-50%); top: 724px; width: 360px; height: 50px;
  border: 1px solid var(--gold-dim); border-radius: 3px; background: linear-gradient(180deg, #2a2119, #1a140f);
  font: 21px CrumbleUI; color: var(--text); text-align: center; line-height: 48px; }
.btn::before, .btn::after { content: "\\25C6"; position: absolute; top: 0; font-size: 9px; color: var(--gold-dim); }
.btn::before { left: 10px; } .btn::after { right: 10px; }
.line-cover { position: absolute; left: 470px; top: 890px; width: 1120px; height: 42px; background: url(bg.png) -470px -940px; }
.line { position: absolute; left: 475px; top: 893px; font: 23px CrumbleText; color: var(--text); }
"""

def card(item, x, cls=""):
    studs = "".join(f'<div class="stud" style="{p}"></div>' for p in (
        "left:-4px;top:-4px", "right:-4px;top:-4px", "left:-4px;bottom:-4px", "right:-4px;bottom:-4px"))
    spells = "".join(f'<div class="spell"><img src="card_{sid}.png"><span>{name}</span></div>'
                     for sid, name in item["spells"])
    glow = item["accent"] + "aa"
    return (f'<div class="card {cls}" style="left:{x}px; --ring:{item["accent"]}; --accent:{item["accent"]}; '
            f'--glow:{glow}">{studs}<div class="tab">{item["slot"]}</div><h2>{item["name"]}</h2>'
            f'<div class="medallion"><img src="{item["id"]}.png"></div><div class="rarity">{item["rarity"]}</div>'
            f'<div class="rule"></div><div class="spells-h">ITS SPELLS</div>{spells}</div>')

def page(body):
    return f"<!doctype html><html><head><meta charset=utf-8><style>{CSS}</style></head><body>{body}</body></html>"

left0 = (1920 - (len(ITEMS) * CARD_W + (len(ITEMS) - 1) * GAP)) // 2
xs = [left0 + i * (CARD_W + GAP) for i in range(len(ITEMS))]
header = ('<div class="header"><div class="eyebrow">LEAVE AN HEIRLOOM</div>'
          '<div class="sub">He offers it back to you at the start of your next run.</div></div>')

choice = header + "".join(card(it, x, "focus" if i == 0 else "dim") for i, (it, x) in enumerate(zip(ITEMS, xs)))
choice += '<div class="btn">Leave nothing</div>'
(HERE / "choice.html").write_text(page(choice))

# Ceremony, about 0.6 s after the choice: the other cards have burned away to rising embers, the chosen piece's art
# lifts out of its medallion and arcs down into the Emaciated Man's portrait, which warms as he takes it.
CEREMONY_CSS = """
.ember { position: absolute; width: 4px; height: 4px; background: #ffb35a; box-shadow: 0 0 6px #ff8a2a; }
.ash { position: absolute; width: 316px; height: 40px; top: 640px;
  background: radial-gradient(ellipse at 50% 100%, rgba(232,137,58,.35), rgba(232,137,58,0) 70%); }
.flying { position: absolute; width: 192px; height: 192px; image-rendering: pixelated;
  filter: drop-shadow(0 0 12px rgba(240,207,138,.95)) drop-shadow(0 0 34px rgba(232,137,58,.65)); }
.trail { position: absolute; width: 16px; height: 16px; border-radius: 50%;
  background: radial-gradient(circle, rgba(255,214,140,.95), rgba(232,137,58,0) 70%); }
.portrait-glow { position: absolute; left: 343px; top: 900px; width: 120px; height: 120px; border-radius: 6px;
  box-shadow: 0 0 0 2px rgba(240,207,138,.8), 0 0 30px rgba(232,137,58,.75); }
.medallion.empty { box-shadow: inset 0 0 0 4px var(--ring), inset 0 0 0 6px #120d0a, 0 0 0 1px var(--gold),
  0 0 40px rgba(240,207,138,.55), inset 0 0 60px rgba(240,207,138,.35); }
"""
import random
random.seed(7)
parts = []
for i, (it, x) in enumerate(zip(ITEMS, xs)):
    if i == 0:
        parts.append(card({**it, "id": "blank"}, x, "focus").replace('class="medallion"', 'class="medallion empty"'))
        continue
    parts.append(f'<div class="ash" style="left:{x}px"></div>')
    for _ in range(26):
        ex = x + random.randint(10, 306); ey = random.randint(180, 660)
        parts.append(f'<div class="ember" style="left:{ex}px; top:{ey}px; opacity:{random.uniform(.25, .95):.2f}"></div>')
path = [(xs[0] + 158, 260), (760, 560), (403, 960)]
def bez(t):
    (x0, y0), (x1, y1), (x2, y2) = path
    return ((1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2, (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2)
fx, fy = bez(0.42)
for k in range(12):
    t = 0.46 + k * 0.045
    tx, ty = bez(t)
    parts.append(f'<div class="trail" style="left:{tx - 8:.0f}px; top:{ty - 8:.0f}px; opacity:{0.85 - k * 0.06:.2f}"></div>')
parts.append(f'<img class="flying" src="duelist_rapier.png" style="left:{fx - 96:.0f}px; top:{fy - 96:.0f}px">')
parts.append('<div class="portrait-glow"></div>')
parts.append('<div class="line-cover"></div><div class="line">I\'ll keep it.</div>')
ceremony = header.replace('class="header"', 'class="header" style="opacity:.45"') + "".join(parts)
(HERE / "ceremony.html").write_text(page(ceremony).replace("</style>", CEREMONY_CSS + "</style>"))
print("ok", xs)
