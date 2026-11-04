#!/usr/bin/env python3
"""Cut a rig reel out of the movie-writer capture: each segment from its 0.4 s idle lead to its tail, in plan order,
picture and sound, then a labelled contact image with one frame per segment (cropped around the enemy).

usage: rig_reel_compose.py <work_dir> <out.mp4> <contact.png> [--crf N] [--title TEXT]
"""
import json, re, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from reel_sync import offset
from PIL import Image, ImageDraw, ImageFont

WORK = Path(sys.argv[1]); MP4 = Path(sys.argv[2]); CONTACT = Path(sys.argv[3])
CRF = int(sys.argv[sys.argv.index("--crf") + 1]) if "--crf" in sys.argv else 24
TITLE = sys.argv[sys.argv.index("--title") + 1] if "--title" in sys.argv else WORK.name
AVI = WORK / "capture.avi"
log = (WORK / "capture.log").read_text()
segments = [json.loads(m) for m in re.findall(r"^REEL SEG (\{.*\})$", log, re.M)]
frames = json.loads((WORK / "capture_out/reel_frames.json").read_text())
# Logged screen points are in the (clamped) window's logical space; the movie is 1920x1080.
WINDOW = json.loads((WORK / "capture_out/reel.json").read_text())["size"]
SCALE_TO_MOVIE = 1920.0 / float(WINDOW[0])
END_GUARD = 2  # never include the next segment's install frame
OFFSET = offset(WORK)  # movie frame = logged frames_drawn + OFFSET

# 1. The reel: trim each segment, concatenate picture and sound.
parts, labels = [], []
for i, s in enumerate(segments):
    a, b = s["pre"] + OFFSET, s["end"] - END_GUARD + OFFSET
    parts.append(f"[0:v]trim=start_frame={a}:end_frame={b},setpts=PTS-STARTPTS[v{i}];"
                 f"[0:a]atrim=start={a/60:.5f}:end={b/60:.5f},asetpts=PTS-STARTPTS[a{i}];")
    labels.append(f"[v{i}][a{i}]")
graph = "".join(parts) + "".join(labels) + f"concat=n={len(segments)}:v=1:a=1[v][a]"
cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(AVI), "-filter_complex", graph,
       "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "slow", "-crf", str(CRF), "-pix_fmt", "yuv420p",
       "-r", "60", "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", "-threads", "2", str(MP4)]
subprocess.run(cmd, check=True)
size = MP4.stat().st_size / 1e6
print(f"REEL {MP4} {size:.1f} MB crf {CRF}")

# 2. Contact image: per segment, the frame nearest the clip's contact (or its middle), cropped around the enemy.
def clip_of(segment):
    rows = [r for r in frames["rows"] if r["seg"] == segment["name"] and segment["start"] <= r["f"] < segment["action_end"]]
    return rows

picks = []
for s in segments:
    rows = clip_of(s)
    shown = [r for r in rows if r.get("clip") not in (None, "idle")] or rows
    if not shown:
        shown = [r for r in frames["rows"] if r["seg"] == s["name"]]
    if s["kind"] == "death":
        death = [r for r in shown if r.get("clip") == "death"]
        pick = min(death, key=lambda r: abs(r["phase"] - 0.3)) if death else shown[len(shown) // 2]
    elif s["kind"] in ("idle",):
        pick = shown[len(shown) // 2]
    else:
        pick = min(shown, key=lambda r: abs(r.get("phase", 0.5) - 0.5))
    picks.append((s, pick))
indices = sorted({p["f"] + OFFSET for _, p in picks})
tmp = WORK / "contact_frames"; tmp.mkdir(exist_ok=True)
for old in tmp.glob("*.png"): old.unlink()
expr = "+".join(f"eq(n\\,{n})" for n in indices)
subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-threads", "2", "-i", str(AVI), "-vf", f"select='{expr}'",
                "-vsync", "0", "-threads", "2", str(tmp / "f_%03d.png")], check=True)
by_frame = {n: tmp / f"f_{k + 1:03d}.png" for k, n in enumerate(indices)}
CW, CH = 360, 330   # 1:1 crop around the enemy's floor point
SCALE = 1.0
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)
big = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 19)
cols = 2
rows_n = (len(picks) + 1) // 2
tw, th = int(CW * SCALE), int(CH * SCALE)
pad, label_h, head = 12, 30, 48
sheet = Image.new("RGB", (cols * (tw + pad) + pad, head + rows_n * (th + label_h + pad) + pad), (18, 18, 22))
draw = ImageDraw.Draw(sheet)
draw.text((pad, 10), TITLE, fill=(235, 235, 235), font=big)
for k, (s, r) in enumerate(picks):
    image = Image.open(by_frame[r["f"] + OFFSET]).convert("RGB")
    x, y = [v * SCALE_TO_MOVIE for v in r.get("screen", [800, 450])]
    box = (int(x - CW / 2), int(y - CH + 70), int(x + CW / 2), int(y + 70))
    tile = image.crop(box).resize((tw, th), Image.LANCZOS)
    col, row = k % 2, k // 2
    ox, oy = pad + col * (tw + pad), head + row * (th + label_h + pad)
    sheet.paste(tile, (ox, oy + label_h))
    phase = f"  (phase {r['phase']:.2f})" if r.get("clip") not in (None, "idle") else ""
    draw.text((ox, oy + 4), f"{s['caption']}{phase}", fill=(235, 235, 235), font=font)
sheet.save(CONTACT)
print("CONTACT", CONTACT, sheet.size)
