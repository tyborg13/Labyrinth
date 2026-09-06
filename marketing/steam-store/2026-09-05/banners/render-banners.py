#!/usr/bin/env python3
"""Render original Steam section banners from vectors + the game's exact font.

Python dependencies: Pillow and fontTools. No external artwork or font fallback.
SVG lettering is outlined from LabyrinthCrumble-Display.ttf so uploads and other
machines reproduce the identity without requiring the font to be installed.
"""
from pathlib import Path
import hashlib
import json
import math
from xml.sax.saxutils import escape

from PIL import Image, ImageDraw, ImageFont
from PIL.PngImagePlugin import PngInfo
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FONT_PATH = ROOT / 'fonts/LabyrinthCrumble-Display.ttf'
WIDTH, HEIGHT, AA = 1170, 176, 3
FONT_SIZE = 56
FACE = TTFont(FONT_PATH)
GLYPHS = FACE.getGlyphSet()
CMAP = FACE.getBestCmap()
UNITS = FACE['head'].unitsPerEm
RASTER_FONT = ImageFont.truetype(str(FONT_PATH), FONT_SIZE * AA)
CREAM, GOLD, DIM_GOLD = '#efe1bd', '#c5a268', '#62523d'
# Authored hex colors are sRGB. A standard PNG sRGB chunk is deterministic and
# makes the intended display space explicit without machine-specific profiles.
COLOR_METADATA = PngInfo()
COLOR_METADATA.add(b'sRGB', bytes([0]))
BANNERS = [
    ('01-set-up-the-next-strike', 'SET UP THE NEXT STRIKE', 'board'),
    ('02-your-gear-builds-your-deck', 'YOUR GEAR BUILDS YOUR DECK', 'gear'),
    ('03-bring-light-into-the-umbra', 'BRING LIGHT INTO THE UMBRA', 'light'),
    ('04-choose-how-far-to-go', 'CHOOSE HOW FAR TO GO', 'route'),
]


def rgba(value):
    value = value.lstrip('#')
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


class Art:
    def __init__(self, label):
        self.image = Image.new('RGBA', (WIDTH * AA, HEIGHT * AA), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.image)
        self.parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-label="{escape(label)}">', f'<title>{escape(label)}</title>']

    def poly(self, pts, fill, stroke=None, width=1):
        points = [(round(x * AA), round(y * AA)) for x, y in pts]
        self.draw.polygon(points, fill=rgba(fill))
        if stroke:
            self.draw.line(points + points[:1], fill=rgba(stroke), width=max(1, round(width * AA)), joint='curve')
        coords = ' '.join(f'{x:.2f},{y:.2f}' for x, y in pts)
        self.parts.append(f'<polygon points="{coords}" fill="{fill}"' + (f' stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"' if stroke else '') + '/>')

    def line(self, pts, color, width=1):
        self.draw.line([(round(x * AA), round(y * AA)) for x, y in pts], fill=rgba(color), width=max(1, round(width * AA)), joint='curve')
        coords = ' '.join(f'{x:.2f},{y:.2f}' for x, y in pts)
        self.parts.append(f'<polyline points="{coords}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round"/>')

    def circle(self, x, y, r, fill, stroke=None, width=1):
        bounds = [(round((x-r)*AA), round((y-r)*AA)), (round((x+r)*AA), round((y+r)*AA))]
        self.draw.ellipse(bounds, fill=rgba(fill), outline=rgba(stroke) if stroke else None, width=max(1, round(width*AA)))
        self.parts.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"' + (f' stroke="{stroke}" stroke-width="{width}"' if stroke else '') + '/>')

    def text(self, value, x, baseline, fill):
        # One glyph layout shared by the two outputs, at the font's own metrics.
        # The small tracking opens the large uppercase line at mobile widths.
        scale = FONT_SIZE / UNITS
        cursor = float(x)
        for char in value:
            glyph_name = CMAP[ord(char)]
            pen = SVGPathPen(GLYPHS)
            GLYPHS[glyph_name].draw(pen)
            path = pen.getCommands()
            if path:
                self.parts.append(f'<path fill="{fill}" transform="translate({cursor:.4f} {baseline}) scale({scale:.8f} {-scale:.8f})" d="{path}"/>')
                self.draw.text((cursor * AA, baseline * AA), char, font=RASTER_FONT, anchor='ls', fill=rgba(fill))
            cursor += FACE['hmtx'][glyph_name][0] * scale + 0.25
        return cursor

    def finish(self, name):
        self.parts.append('</svg>')
        (HERE / f'{name}.svg').write_text('\n'.join(self.parts) + '\n')
        result = self.image.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
        result.save(HERE / f'{name}.png', optimize=True, pnginfo=COLOR_METADATA)
        return result


def diamond(x, y, w, h):
    return [(x, y-h), (x+w, y), (x, y+h), (x-w, y)]


def frame(art, kind):
    # Cut stone ends, inset masonry facets, and a double broken gilded rail.
    # All geometry is original; these are section ornaments, not gameplay icons.
    art.poly([(23, 8), (1138, 8), (1165, 35), (1165, 140), (1138, 167), (23, 167), (5, 149), (5, 26)], '#0d0d12')
    art.poly([(26, 12), (1136, 12), (1160, 37), (1160, 138), (1136, 162), (26, 162), (10, 146), (10, 28)], '#19171a', '#766044', 1.4)
    art.poly([(11, 29), (27, 13), (157, 13), (202, 54), (175, 162), (27, 162), (11, 146)], '#211c20')
    art.poly([(158, 13), (390, 13), (362, 29), (202, 54)], '#252026')
    art.poly([(1094, 13), (1136, 13), (1160, 37), (1160, 138), (1136, 162), (1081, 162), (1119, 89)], '#22202a')
    art.poly([(27, 147), (356, 147), (383, 162), (27, 162), (11, 146), (11, 132)], '#100f15')
    art.line([(27, 37), (27, 27), (160, 27)], GOLD, 1.8)
    art.line([(206, 27), (1070, 27)], DIM_GOLD, 1)
    art.line([(1070, 27), (1127, 27), (1145, 45)], GOLD, 1.8)
    art.line([(27, 138), (27, 148), (160, 148)], GOLD, 1.8)
    art.line([(206, 148), (1070, 148)], DIM_GOLD, 1)
    art.line([(1070, 148), (1127, 148), (1145, 130)], GOLD, 1.8)
    art.line([(183, 47), (183, 69)], '#58463b', 1.5)
    art.line([(183, 107), (183, 129)], '#58463b', 1.5)
    art.poly(diamond(183, 88, 5, 7), '#9d7a4d')
    # Irregular hairline fractures create stone structure without noisy texture.
    art.line([(339, 13), (325, 22), (334, 27)], '#3a3030', 1)
    art.line([(847, 148), (857, 156), (851, 162)], '#342b2c', 1)
    art.line([(1146, 62), (1154, 77), (1147, 96)], '#38313c', 1)
    # Four paired end-cap notches repeat a restrained card-border rhythm.
    for y in (64, 76, 100, 112):
        art.line([(1138, y), (1145, y+4)], '#54463f', 1)
    if kind == 'light':
        art.poly([(29, 66), (57, 43), (144, 47), (162, 73), (154, 124), (112, 143), (52, 126)], '#282331')
    else:
        art.poly([(43, 60), (73, 36), (137, 46), (163, 91), (140, 136), (65, 139), (33, 112)], '#292021')


# Material and light rendering stays separate from the approved frame and type.
from dimensional_motifs import board, gear, light, route


def main():
    images = []
    outputs = []
    for stem, heading, kind in BANNERS:
        art = Art(heading)
        frame(art, kind)
        globals()[kind](art)
        # Shadow follows the same real glyph contours; nothing replaces the font.
        art.text(heading, 226, 111, '#08090d')
        extent = art.text(heading, 225, 109, CREAM)
        if extent > 1118:
            raise ValueError(f'Heading exceeds its authored safe area: {heading}: {extent}')
        img = art.finish(stem)
        images.append(img)
        outputs.append({'stem': stem, 'heading': heading, 'size': [WIDTH, HEIGHT], 'text_right': round(extent, 2), 'png_sha256': hashlib.sha256((HERE / f'{stem}.png').read_bytes()).hexdigest()})
    for width in (1170, 780, 390):
        height = round(HEIGHT * width / WIDTH)
        gap = max(8, round(18 * width / WIDTH))
        sheet = Image.new('RGB', (width, (height+gap)*len(images)+gap), '#1b2838')
        for i, img in enumerate(images):
            scaled = img.resize((width, height), Image.Resampling.LANCZOS)
            sheet.paste(scaled, (0, gap+i*(height+gap)), scaled)
        sheet.save(HERE / f'preview-{width}.png', optimize=True, pnginfo=COLOR_METADATA)
    (HERE / 'manifest.json').write_text(json.dumps({'font': 'fonts/LabyrinthCrumble-Display.ttf', 'font_sha256': hashlib.sha256(FONT_PATH.read_bytes()).hexdigest(), 'font_size': FONT_SIZE, 'color_space': 'sRGB', 'png_color_metadata': 'standard sRGB chunk, perceptual intent', 'motif_style': 'original shaded vector miniatures with soft radial light', 'svg_text': 'outlined from source font', 'outputs': outputs}, indent=2)+'\n')
    print(f'Rendered {len(images)} banners at {WIDTH}x{HEIGHT}; previews at 1170, 780, 390 pixels wide.')


if __name__ == '__main__':
    main()
