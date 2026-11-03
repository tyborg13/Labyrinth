"""Director mockup: unit status/defense nameplates on the real 1920x1080 board capture (clean board + real icons/fonts)."""
import json, sys
from PIL import Image, ImageDraw, ImageFont

S = sys.argv[1]
ICONS = sys.argv[2]
VARIANT = sys.argv[3]  # 'A' icons+counts, 'B' control statuses add a word
board = Image.open(f'{S}/clean_board.png').convert('RGBA')
bars = json.load(open(f'{S}/bars.json'))
UI = f'{S}/UI.ttf'

def font(size):
    return ImageFont.truetype(UI, size)

INK = (20, 16, 13, 238)
CONTROL = (255, 138, 77)     # can't act / limited this turn
VULN = (226, 76, 92)         # takes more / loses health
BUFF = (232, 198, 106)       # helps its holder
BLOCK = (143, 201, 236)
STONE = (174, 190, 140)
WORD = {'freeze': 'Frozen', 'shock': 'Shocked', 'petrify': 'Petrified', 'immobilize': 'Immobilized', 'chilled': 'Chilled'}
CLASS = {'freeze': CONTROL, 'shock': CONTROL, 'petrify': CONTROL, 'immobilize': CONTROL,
         'bleed': VULN, 'expose': VULN, 'chilled': VULN, 'retaliate': BUFF, 'quicken': BUFF}

# Units in bar order (detected): hero, Thornmother(top), knight(right), left grub, mid grub, low grub.
UNITS = [
    {'defense': [('block', 6), ('stoneskin', 4)], 'statuses': [('bleed', 2), ('expose', 1)]},
    {'defense': [('stoneskin', 3)], 'statuses': [('immobilize', 0), ('bleed', 3), ('expose', 2)]},
    {'defense': [('block', 5), ('stoneskin', 3)], 'statuses': [('shock', 0), ('chilled', 0)]},
    {'defense': [('stoneskin', 2)], 'statuses': [('petrify', 0), ('bleed', 1)]},
    {'defense': [('block', 8)], 'statuses': [('freeze', 0)]},
    {'defense': [], 'statuses': []},
]

def icon(key, side):
    im = Image.open(f'{ICONS}/{key}.png').convert('RGBA')
    bbox = im.getbbox()
    im = im.crop(bbox)
    scale = side / max(im.size)
    return im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)

def outlined(draw, xy, text, f, fill, outline=(10, 7, 5, 255), width=2):
    x, y = xy
    for dx in range(-width, width + 1):
        for dy in range(-width, width + 1):
            if dx or dy:
                draw.text((x + dx, y + dy), text, font=f, fill=outline)
    draw.text((x, y), text, font=f, fill=fill)

def plate(layer, x, y, key, value, border):
    d = ImageDraw.Draw(layer)
    f = font(17)
    tw = d.textlength(str(value), font=f)
    w, h = int(24 + 4 + tw + 9), 24
    d.rounded_rectangle([x, y, x + w, y + h], radius=5, fill=INK, outline=border + (255,), width=2)
    d.line([x + 3, y + 3, x + w - 3, y + 3], fill=border + (90,), width=1)
    ic = icon(key, 20)
    layer.alpha_composite(ic, (x + 4 + (20 - ic.width) // 2, y + 2 + (20 - ic.height) // 2))
    outlined(d, (x + 27, y + 1), str(value), f, (246, 248, 255, 255))
    return w

def pill(layer, x, y, key, count):
    d = ImageDraw.Draw(layer)
    border = CLASS[key]
    label = ''
    if count:
        label = str(count)
    elif VARIANT == 'B' and key in WORD:
        label = WORD[key]
    f = font(15 if count else 13)
    tw = d.textlength(label, font=f) if label else 0
    w, h = int(22 + (6 + tw if label else 2) + 4), 22
    d.rounded_rectangle([x, y, x + w, y + h], radius=11, fill=INK, outline=border + (255,), width=2)
    ic = icon(key, 18)
    layer.alpha_composite(ic, (x + 3 + (18 - ic.width) // 2, y + 2 + (18 - ic.height) // 2))
    if label:
        outlined(d, (x + 24, y + (1 if count else 3)), label, f, (255, 244, 226, 255), width=1)
    return w

layer = Image.new('RGBA', board.size, (0, 0, 0, 0))
for bar, unit in zip(bars, UNITS):
    hero = bar['kind'] == 'teal'
    cap = 14 if hero else 22          # frame end cap beyond the fill
    bar_y = bar['y0'] - 7             # frame top
    x = bar['x1'] + cap + 2
    for key, value in unit['defense']:
        x += plate(layer, x, bar_y, key, value, BLOCK if key == 'block' else STONE) + 3
    px = bar['x0'] - (4 if hero else 10)
    py = bar['y1'] + 9
    order = sorted(unit['statuses'], key=lambda s: [CONTROL, VULN, BUFF].index(CLASS[s[0]]))
    for key, count in order:
        px += pill(layer, px, py, key, count) + 4
board.alpha_composite(layer)
board.convert('RGB').save(f'{S}/mock_{VARIANT}.png')
print('wrote', f'{S}/mock_{VARIANT}.png')
