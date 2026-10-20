import sys
from PIL import Image, ImageDraw
src, out, cx, cy, w, h = sys.argv[1], sys.argv[2], *map(float, sys.argv[3:7])
im = Image.open(src).convert("RGBA"); ov = Image.new("RGBA", im.size); d = ImageDraw.Draw(ov)
for i in range(int(sys.argv[7]) if len(sys.argv)>7 else 7):
    for j in range(int(sys.argv[7]) if len(sys.argv)>7 else 7):
        x = cx + (i - j) * w / 2; y = cy + (i + j) * h / 2
        d.polygon([(x, y - h/2), (x + w/2, y), (x, y + h/2), (x - w/2, y)], outline=(0, 255, 255, 255))
        d.text((x - 8, y - 6), f"{i}{j}", fill=(255, 255, 0, 255))
Image.alpha_composite(im, ov).convert("RGB").crop((380, 120, 1540, 780)).save(out)
