"""Compose the shrike's native clip renders into a real-time 60 fps review video (front | rear), piped to ffmpeg."""
import glob, subprocess, sys
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1], sys.argv[2]
plan = [("idle", 3), ("move", 3), ("dive", 2), ("talon_rake", 2), ("hover", 2), ("hit", 2), ("death", 1)]
W, H, BG = 1920, 1080, (30, 30, 36)
try: font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 40)
except Exception: font = ImageFont.load_default()
def frames(view, clip): return sorted(glob.glob(f"{src}/{view}_{clip}/pose_0*.png"))
ff = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", "60",
                       "-i", "-", "-threads", "2", "-c:v", "libx264", "-crf", "16", "-preset", "medium", "-pix_fmt", "yuv420p", out],
                      stdin=subprocess.PIPE)
total = 0
for clip, loops in plan:
    fr, rr = frames("front", clip), frames("rear", clip)
    n = min(len(fr), len(rr)); print(clip, n, "frames")
    seq = list(range(n)) * loops + ([n - 1] * 60 if clip == "death" else [])
    for i in seq:
        canvas = Image.new("RGB", (W, H), BG)
        for k, path in enumerate((fr[i], rr[i])):
            im = Image.open(path).convert("RGBA"); im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
            x = (W // 4) * (1 + 2 * k) - im.width // 2; y = H // 2 - im.height // 2 + 40
            canvas.paste(im, (x, y), im)
        d = ImageDraw.Draw(canvas); label = clip.replace("_", " ").upper()
        d.text((W // 2 - d.textlength(label, font=font) // 2, 60), label, fill=(237, 228, 211), font=font)
        ff.stdin.write(canvas.tobytes()); total += 1
ff.stdin.close(); ff.wait(); print("frames", total, "seconds", round(total / 60, 1))
