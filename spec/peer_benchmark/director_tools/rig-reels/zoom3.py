#!/usr/bin/env python3
"""3x zoom of the enemy body only, N frames across its clip: zoom3.py <work> <segment> <out.png> [N] [w h]"""
import json, re, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from reel_sync import offset
from PIL import Image, ImageDraw, ImageFont
WORK = Path(sys.argv[1]); NAME = sys.argv[2]; OUT = Path(sys.argv[3]); N = int(sys.argv[4]) if len(sys.argv) > 4 else 8
W, H = (int(sys.argv[5]), int(sys.argv[6])) if len(sys.argv) > 6 else (150, 190)
O = offset(WORK)
rows = [r for r in json.loads((WORK / "capture_out/reel_frames.json").read_text())["rows"] if r["seg"] == NAME and r.get("clip") not in (None, "idle")]
k = 1920.0 / json.loads((WORK / "capture_out/reel.json").read_text())["size"][0]
picks = [rows[round(i * (len(rows) - 1) / (N - 1))] for i in range(N)]
tmp = WORK / "zoom_tmp"; tmp.mkdir(exist_ok=True)
for old in tmp.glob("*.png"): old.unlink()
expr = "+".join(f"eq(n\\,{r['f'] + O})" for r in picks)
subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(WORK / "capture.avi"), "-vf", f"select='{expr}'", "-vsync", "0", "-threads", "2", str(tmp / "z_%03d.png")], check=True)
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
sheet = Image.new("RGB", (N * W * 3, H * 3 + 24), (16, 16, 20)); d = ImageDraw.Draw(sheet)
for i, r in enumerate(picks):
    x, y = r["screen"][0] * k, r["screen"][1] * k
    im = Image.open(tmp / f"z_{i + 1:03d}.png").convert("RGB").crop((int(x - W / 2), int(y - H + 20), int(x + W / 2), int(y + 20)))
    sheet.paste(im.resize((W * 3, H * 3), Image.NEAREST), (i * W * 3, 24))
    d.text((i * W * 3 + 4, 3), f"f{r['f']} {r['clip']} {r['phase']}", fill=(230, 230, 230), font=font)
sheet.save(OUT); print(OUT, sheet.size)
