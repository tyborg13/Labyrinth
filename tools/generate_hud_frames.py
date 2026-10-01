#!/usr/bin/env python3
"""Render the combat HUD frame art in the shared "gilded glass" language.

The frames are authored at 2x their layout size (the HUD draws them scaled
down), supersampled 4x for clean anti-aliased hairlines, and use the same
palette as scripts/ui_palette.gd. Requires Pillow and numpy.

    python3 tools/generate_hud_frames.py
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "art" / "ui" / "hud_v3"
SUPER = 4  # supersampling factor relative to the 2x output
SCALE = 2  # output scale relative to layout size

INK_0 = (11, 9, 8)
INK_1 = (21, 17, 14)
INK_2 = (31, 24, 19)
GOLD_DIM = (124, 98, 64)
GOLD = (201, 162, 94)
GOLD_BRIGHT = (240, 207, 138)
EMBER = (232, 137, 58)


def _s(value: float) -> float:
    """Layout units -> supersampled canvas pixels."""
    return value * SCALE * SUPER


def cut_poly(x0: float, y0: float, x1: float, y1: float, cut: float) -> list[tuple[float, float]]:
    return [
        (x0 + cut, y0), (x1 - cut, y0), (x1, y0 + cut), (x1, y1 - cut),
        (x1 - cut, y1), (x0 + cut, y1), (x0, y1 - cut), (x0, y0 + cut),
    ]


def _mask(size: tuple[int, int], poly: list[tuple[float, float]]) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(poly, fill=255)
    return mask


def _gradient(size: tuple[int, int], top: tuple, bottom: tuple, y0: float, y1: float, grain: float = 0.0, seed: int = 7) -> Image.Image:
    w, h = size
    t = np.clip((np.arange(h, dtype=np.float64) - y0) / max(1.0, y1 - y0), 0.0, 1.0)[:, None]
    top_a = np.array(top, dtype=np.float64)
    bottom_a = np.array(bottom, dtype=np.float64)
    rgb = top_a[None, None, :] * (1.0 - t[..., None]) + bottom_a[None, None, :] * t[..., None]
    rgb = np.broadcast_to(rgb, (h, w, 3)).copy()
    if grain > 0.0:
        rng = np.random.default_rng(seed)
        noise = rng.normal(0.0, 1.0, (h // SUPER + 1, w // SUPER + 1))
        noise = np.kron(noise, np.ones((SUPER, SUPER)))[:h, :w]
        rgb += noise[..., None] * grain
    rgba = np.concatenate([np.clip(rgb, 0, 255), np.full((h, w, 1), 255.0)], axis=2)
    return Image.fromarray(rgba.astype(np.uint8))


def fill_poly(canvas: Image.Image, poly, top, bottom, grain: float = 3.0, alpha: int = 255) -> None:
    ys = [p[1] for p in poly]
    fill = _gradient(canvas.size, top, bottom, min(ys), max(ys), grain)
    mask = _mask(canvas.size, poly)
    if alpha < 255:
        mask = mask.point(lambda v: v * alpha // 255)
    canvas.alpha_composite(Image.composite(fill, Image.new("RGBA", canvas.size, (0, 0, 0, 0)), mask))


def stroke_poly(canvas: Image.Image, poly, color, width_px: float) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).line(poly + [poly[0]], fill=color, width=max(1, int(round(width_px))), joint="curve")
    canvas.alpha_composite(layer)


def glow_poly(canvas: Image.Image, poly, color, radius_px: float, strength: float = 1.0) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).line(poly + [poly[0]], fill=color + (int(255 * strength),), width=int(radius_px * 0.6), joint="curve")
    layer = layer.filter(ImageFilter.GaussianBlur(radius_px))
    canvas.alpha_composite(layer)


def diamond(canvas: Image.Image, cx: float, cy: float, r: float, color=GOLD) -> None:
    d = ImageDraw.Draw(canvas)
    d.polygon([(cx, cy - r * 1.25), (cx + r * 1.25, cy), (cx, cy + r * 1.25), (cx - r * 1.25, cy)], fill=INK_0 + (235,))
    bright = tuple(int(c * 0.65 + g * 0.35) for c, g in zip(color, GOLD_BRIGHT))
    d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=bright + (255,))
    d.line([(cx - r * 0.35, cy - r * 0.2), (cx, cy - r * 0.6)], fill=(255, 245, 215, 200), width=max(1, int(r * 0.22)))


def catch_light(canvas: Image.Image, cx: float, y: float, half: float, alpha: float) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 40
    for i in range(steps):
        a = i / steps
        b = (i + 1) / steps
        fade = 1.0 - abs((a + b) * 0.5 - 0.5) * 2.0
        d.line([(cx - half + a * half * 2, y), (cx - half + b * half * 2, y)], fill=(255, 238, 196, int(255 * alpha * fade)), width=int(_s(1.0)))
    canvas.alpha_composite(layer)


def sheen(canvas: Image.Image, poly, strength: float = 1.0) -> None:
    ys = [p[1] for p in poly]
    y0, y1 = min(ys), max(ys)
    w, h = canvas.size
    t = np.clip((np.arange(h, dtype=np.float64) - y0) / max(1.0, y1 - y0), 0.0, 1.0)
    light = np.clip(1.0 - t / 0.5, 0.0, 1.0) * 0.10 * strength
    dark = np.clip((t - 0.55) / 0.45, 0.0, 1.0) * 0.26 * strength
    rgba = np.zeros((h, w, 4))
    rgba[..., 0:3] = np.where((light > 0)[:, None, None], np.array([255, 232, 190]), 0)
    rgba[..., 3] = np.maximum(light, 0)[:, None] * 255
    top = Image.fromarray(rgba.astype(np.uint8))
    rgba2 = np.zeros((h, w, 4))
    rgba2[..., 3] = dark[:, None] * 255
    bottom = Image.fromarray(rgba2.astype(np.uint8))
    mask = _mask(canvas.size, poly)
    empty = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    canvas.alpha_composite(Image.composite(top, empty, mask))
    canvas.alpha_composite(Image.composite(bottom, empty, mask))


def finish(canvas: Image.Image, layout_size: tuple[int, int], name: str) -> None:
    out = canvas.resize((layout_size[0] * SCALE, layout_size[1] * SCALE), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / name, optimize=True)
    print(f"{name}: {out.size[0]}x{out.size[1]}")


def pass_frame(state: str) -> None:
    """End-turn plate (270x100): ember-bronze command plate over a forecast ribbon."""
    w, h = 270, 100
    canvas = Image.new("RGBA", (int(_s(w)), int(_s(h))), (0, 0, 0, 0))
    plate = cut_poly(_s(8), _s(6), _s(w - 8), _s(64), _s(7))
    ribbon = cut_poly(_s(34), _s(67), _s(w - 34), _s(93), _s(5))
    hover = state == "hover"
    pressed = state == "pressed"
    # Drop shadow under both plates.
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x, y + _s(4)) for x, y in plate], fill=(0, 0, 0, 200))
    ImageDraw.Draw(shadow).polygon([(x, y + _s(3)) for x, y in ribbon], fill=(0, 0, 0, 170))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(_s(4))))
    if not pressed:
        glow_poly(canvas, plate, EMBER, _s(7 if hover else 5), 0.85 if hover else 0.55)
    top = (148, 84, 34) if hover else ((88, 50, 22) if pressed else (118, 66, 27))
    bottom = (74, 38, 15) if hover else ((44, 24, 11) if pressed else (58, 31, 13))
    fill_poly(canvas, plate, top, bottom, grain=3.5)
    sheen(canvas, plate, 0.5 if pressed else (1.3 if hover else 1.0))
    edge = GOLD_BRIGHT if hover else (GOLD if not pressed else (170, 132, 76))
    stroke_poly(canvas, plate, edge + (255,), _s(1.25))
    inner = cut_poly(_s(12), _s(10), _s(w - 12), _s(60), _s(5))
    stroke_poly(canvas, inner, edge + (95 if not pressed else 60,), _s(1.0))
    if not pressed:
        catch_light(canvas, _s(w / 2), _s(6.6), _s(78), 0.85 if hover else 0.6)
    for cx in (_s(16), _s(w - 16)):
        diamond(canvas, cx, _s(35), _s(3.4), GOLD_BRIGHT if hover else GOLD)
    # Forecast ribbon: dark glass, so the coloured forecast text stays legible.
    fill_poly(canvas, ribbon, INK_2, INK_0, grain=2.0)
    stroke_poly(canvas, ribbon, GOLD_DIM + (255,), _s(1.0))
    for cx in (_s(34), _s(w - 34)):
        diamond(canvas, cx, _s(80), _s(2.6), GOLD)
    name = {"normal": "pass_command_frame.png", "hover": "pass_command_frame_hover.png", "pressed": "pass_command_frame_pressed.png"}[state]
    finish(canvas, (w, h), name)


def meter_frame() -> None:
    """Resource meter (228x58): round gilt icon socket beside a dark glass plate."""
    w, h = 228, 58
    canvas = Image.new("RGBA", (int(_s(w)), int(_s(h))), (0, 0, 0, 0))
    plate = cut_poly(_s(26), _s(9), _s(w - 4), _s(h - 9), _s(6))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x, y + _s(3)) for x, y in plate], fill=(0, 0, 0, 190))
    ImageDraw.Draw(shadow).ellipse([_s(3), _s(4) + _s(3), _s(55), _s(56) + _s(3)], fill=(0, 0, 0, 200))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(_s(3.5))))
    fill_poly(canvas, plate, (36, 28, 22), (18, 14, 11), grain=2.5, alpha=240)
    sheen(canvas, plate, 0.9)
    stroke_poly(canvas, plate, GOLD_DIM + (255,), _s(1.1))
    inner = cut_poly(_s(30), _s(13), _s(w - 8), _s(h - 13), _s(4))
    stroke_poly(canvas, inner, GOLD + (60,), _s(1.0))
    catch_light(canvas, _s(140), _s(9.6), _s(60), 0.45)
    diamond(canvas, _s(w - 4), _s(h / 2), _s(3.0), GOLD)
    # Icon socket: dark well inside a double gilt ring.
    d = ImageDraw.Draw(canvas)
    cx, cy, r = _s(29), _s(29), _s(25)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=INK_0 + (255,))
    socket = _gradient(canvas.size, (46, 34, 25), (14, 11, 9), cy - r, cy + r, grain=2.0)
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).ellipse([cx - r + _s(3), cy - r + _s(3), cx + r - _s(3), cy + r - _s(3)], fill=255)
    canvas.alpha_composite(Image.composite(socket, Image.new("RGBA", canvas.size, (0, 0, 0, 0)), mask))
    d = ImageDraw.Draw(canvas)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=GOLD + (255,), width=int(_s(1.4)))
    d.ellipse([cx - r + _s(3.5), cy - r + _s(3.5), cx + r - _s(3.5), cy + r - _s(3.5)], outline=GOLD_DIM + (200,), width=int(_s(1.0)))
    for angle in (math.pi * 1.5, math.pi * 0.5, math.pi, 0.0):
        diamond(canvas, cx + math.cos(angle) * r, cy + math.sin(angle) * r, _s(2.4), GOLD)
    finish(canvas, (w, h), "resource_meter_frame.png")


def main() -> None:
    for state in ("normal", "hover", "pressed"):
        pass_frame(state)
    meter_frame()


if __name__ == "__main__":
    main()
