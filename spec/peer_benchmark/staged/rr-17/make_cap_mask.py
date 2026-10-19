"""Director cut (rr-17): which pixels of the Storm Capacitor painting belong to the cap.

The cap is the dome and spike: every opaque pixel on or above the dome's lower dark outline, for x 86..168. The top
band's raised copper end blocks (x <= 95 or x >= 161, rows >= 52, copper-coloured) stay with the column. Every other
pixel is the column. Writes a 255x255 mask: opaque white = cap.
Run: python3 spec/peer_benchmark/staged/rr-17/make_cap_mask.py <painting.png> <out.png>
"""
import sys
from PIL import Image


def dome_bottom(px, x):
    """Last row of the first dark run at or below row 58: the dome's lower outline at this column."""
    dark = [y for y in range(58, 80) if px[x, y][3] and sum(px[x, y][:3]) < 40]
    if not dark:
        return None
    end = dark[0]
    for y in dark[1:]:
        if y != end + 1:
            break
        end = y
    return end


def main(painting, out):
    art = Image.open(painting).convert('RGBA')
    px = art.load()
    mask = Image.new('RGBA', art.size, (0, 0, 0, 0))
    m = mask.load()
    found = {x: dome_bottom(px, x) for x in range(86, 169)}
    known = sorted(x for x, y in found.items() if y is not None)
    for x in range(86, 169):
        if found[x] is None:  # a lighter outline pixel: take the nearer neighbours' rows
            left = max((k for k in known if k < x), default=None)
            right = min((k for k in known if k > x), default=None)
            found[x] = max(found[k] for k in (left, right) if k is not None)
    for x in range(86, 169):
        for y in range(0, found[x] + 1):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if (x <= 95 or x >= 161) and y >= 52 and r > 110 and r > 1.6 * g:
                continue
            m[x, y] = (255, 255, 255, 255)
    mask.save(out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
