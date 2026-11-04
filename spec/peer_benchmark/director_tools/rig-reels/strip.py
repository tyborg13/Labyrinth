#!/usr/bin/env python3
"""Inspection strip: N evenly spaced frames of one segment (pre-roll to end), cropped around the enemy, from the AVI.
usage: strip.py <work_dir> <segment> <out.png> [count] [--wide]"""
import json, re, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from reel_sync import offset
from PIL import Image, ImageDraw, ImageFont

WORK = Path(sys.argv[1]); NAME = sys.argv[2]; OUT = Path(sys.argv[3])
COUNT = int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4].isdigit() else 12
WIDE = "--wide" in sys.argv
log = (WORK / "capture.log").read_text()
seg = next(json.loads(m) for m in re.findall(r"^REEL SEG (\{.*\})$", log, re.M) if json.loads(m)["name"] == NAME)
rows = {r["f"]: r for r in json.loads((WORK / "capture_out/reel_frames.json").read_text())["rows"] if r["seg"] == NAME}
window = json.loads((WORK / "capture_out/reel.json").read_text())["size"]
k = 1920.0 / window[0]
O = offset(WORK)
a, b = seg["pre"], seg["end"] - 2
if "--clip" in sys.argv:
    # Only the frames that show the segment's own clip (not the idle lead or tail).
    shown = sorted(f for f, r in rows.items() if r.get("clip") not in (None, "idle"))
    a, b = (shown[0], shown[-1]) if shown else (a, b)
picks = [round(a + i * (b - a) / (COUNT - 1)) for i in range(COUNT)]
tmp = WORK / "strip_tmp"; tmp.mkdir(exist_ok=True)
for old in tmp.glob("*.png"): old.unlink()
expr = "+".join(f"eq(n\\,{n + O})" for n in picks)
subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(WORK / "capture.avi"), "-vf", f"select='{expr}'",
                "-vsync", "0", "-threads", "2", str(tmp / "s_%03d.png")], check=True)
W, H = (640, 400) if WIDE else (330, 330)
ZOOM = "--zoom" in sys.argv
if ZOOM: W, H = 220, 250
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)
cols = 6
Z = 2 if ZOOM else 1
sheet = Image.new("RGB", (cols * W * Z, ((COUNT + cols - 1) // cols) * (H * Z + 22)), (16, 16, 20))
draw = ImageDraw.Draw(sheet)
pts = [r["screen"] for r in rows.values() if "screen" in r]
cx = sum(p[0] for p in pts) / len(pts) * k; cy = sum(p[1] for p in pts) / len(pts) * k
for i, n in enumerate(picks):
    im = Image.open(tmp / f"s_{i + 1:03d}.png").convert("RGB")
    r = rows.get(n, {})
    px, py = (r["screen"][0] * k, r["screen"][1] * k) if "screen" in r else (cx, cy)
    if not ZOOM: px, py = cx, cy
    box = (int(px - W / 2), int(py - H + (40 if ZOOM else 80)), int(px + W / 2), int(py + (40 if ZOOM else 80)))
    tile = im.crop(box)
    if ZOOM: tile = tile.resize((W * 2, H * 2), Image.NEAREST)
    x, y = (i % cols) * W * (2 if ZOOM else 1), (i // cols) * (H * (2 if ZOOM else 1) + 22)
    sheet.paste(tile, (x, y + 22))
    draw.text((x + 4, y + 3), f"f{n} {r.get('clip')} {r.get('phase')} {r.get('facing')}{'/M' if r.get('mirrored') else ''}", fill=(230, 230, 230), font=font)
sheet.save(OUT)
print(OUT, sheet.size)
