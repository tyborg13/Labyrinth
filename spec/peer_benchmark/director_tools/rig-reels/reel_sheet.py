#!/usr/bin/env python3
"""Check sheet of a finished reel: one frame every STEP seconds (time-stamped), cropped to the board's centre."""
import subprocess, sys, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
MP4, OUT = sys.argv[1], sys.argv[2]
STEP = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
CROP = sys.argv[4] if len(sys.argv) > 4 else "1100:620:410:0"
tmp = Path(tempfile.mkdtemp())
subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", MP4, "-vf", f"fps={1/STEP},crop={CROP},scale=330:-1",
                "-threads", "2", str(tmp / "r_%04d.png")], check=True)
files = sorted(tmp.glob("r_*.png"))
w, h = Image.open(files[0]).size
cols = 10
sheet = Image.new("RGB", (cols * w, ((len(files) + cols - 1) // cols) * (h + 16)), (0, 0, 0))
d = ImageDraw.Draw(sheet); font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 13)
for i, f in enumerate(files):
    x, y = (i % cols) * w, (i // cols) * (h + 16)
    sheet.paste(Image.open(f), (x, y + 16)); d.text((x + 3, y + 1), f"{i * STEP:.1f}s", fill=(255, 255, 0), font=font)
sheet.save(OUT); print(OUT, sheet.size, len(files))
