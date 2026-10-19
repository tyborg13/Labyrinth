"""Director art (rr-17): the Storm Capacitor's vent, painted under the cap.

When the cap lifts (idle buzz 1 px, Charge 3 px, Arc Burst 6 px, death 8 px and askew) it uncovers the top of the
column: the top band's copper lip and, inside it, the glass column's top with the violet glow. This writes that
hidden fill as a 255x255 RGBA layer aligned to `assets/art/enemies/storm_capacitor.png`, clipped to that painting's
opaque silhouette. The column layer shows it only where the cap no longer covers it. Colours are sampled from the
painting. Deterministic; the painting is the only input.
Run: python3 spec/peer_benchmark/staged/rr-17/make_vent_fill.py <painting.png> <out.png>
"""
import sys
from PIL import Image

OUTLINE = (10, 7, 8, 255)
LIP_HI, LIP, LIP_MID, LIP_LO = (211, 138, 86, 255), (178, 108, 64, 255), (155, 84, 48, 255), (110, 58, 34, 255)
WALL_HI, WALL, WALL_LO = (120, 64, 40, 255), (84, 44, 28, 255), (52, 26, 20, 255)
GLASS_DARK, GLASS = (24, 11, 13, 255), (40, 18, 30, 255)
GLOW_LO, GLOW, GLOW_HI = (71, 28, 69, 255), (122, 63, 184, 255), (180, 110, 246, 255)

CX, CY = 131, 62          # ring centre on the column axis, top band height
OUTER = (47, 15)          # outer lip ellipse semi-axes
INNER = (43, 12)          # inner edge of the lip
GLOW_E = (30, 5)          # glow pool on the glass top, toward the front so a vent shows it
CORE_E = (15, 2)          # bright core
GY = CY + 6               # glow centre row


def inside(x, y, axes, cy=CY):
    a, b = axes
    return ((x + .5 - CX) / a) ** 2 + ((y + .5 - cy) / b) ** 2 <= 1.0


def main(painting, out):
    art = Image.open(painting).convert('RGBA').load()
    img = Image.new('RGBA', (255, 255), (0, 0, 0, 0))
    px = img.load()
    for y in range(CY - OUTER[1] - 1, CY + OUTER[1] + 2):
        for x in range(CX - OUTER[0] - 1, CX + OUTER[0] + 2):
            if not inside(x, y, OUTER):
                continue
            if not inside(x, y, (OUTER[0] - 1, OUTER[1] - 1)):
                px[x, y] = OUTLINE                      # one dark block around the lip
            elif not inside(x, y, INNER):
                # top surface of the copper lip, lit from the upper left; the front lip catches the most light
                front = y >= CY
                left = x < CX - 8
                px[x, y] = (LIP_HI if front and left else LIP if front else LIP_MID if left else LIP_LO)
            elif y < CY - 4:
                # back inner wall of the band, seen through the opening: darker toward the rim
                px[x, y] = WALL_LO if y < CY - 9 else WALL if y < CY - 6 else WALL_HI
            elif inside(x, y, CORE_E, GY):
                px[x, y] = GLOW_HI
            elif inside(x, y, GLOW_E, GY):
                px[x, y] = GLOW if inside(x, y, (GLOW_E[0] - 8, GLOW_E[1] - 1), GY) else GLOW_LO
            else:
                px[x, y] = GLASS if y >= CY else GLASS_DARK
    # the inner edge of the front lip is a one-pixel shadow line where the lip turns down into the opening
    for x in range(CX - INNER[0], CX + INNER[0] + 1):
        for y in range(CY, CY + INNER[1] + 1):
            if inside(x, y, INNER) and not inside(x, y + 1, INNER) and not inside(x, y, GLOW_E, GY):
                px[x, y] = WALL_LO
    for y in range(255):
        for x in range(255):
            if art[x, y][3] == 0:
                px[x, y] = (0, 0, 0, 0)
    img.save(out)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
