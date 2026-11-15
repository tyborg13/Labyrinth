#!/usr/bin/env python3
"""atk-08: compose one labelled frame strip from a strip.gd capture (proof tool).

Picks about 8 frames across the event (each hero number's first frame and the
middle of its life, filled evenly from just before the first number to just after
the last) and lays them out 4x2 at half size with the presentation time of each
frame, the hero numbers on screen and the action banner.

  python3 tools/atk08/strip.py <capture dir> <out.png> [--title TEXT] [--count 8]
      [--crop X0 Y0 X1 Y1] [--times T ...]

atk-10: --crop keeps one 1920x1080 region (the rail and the hero together) at
full size; --times picks the frames nearest those presentation times; each
label names the rail's active entry and the foe acting.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FONT = Path(__file__).resolve().parents[2] / "fonts/LabyrinthCrumble-UI.ttf"
THUMB = (960, 540)
LABEL = 54


def pick(frames: list[dict], count: int) -> list[dict]:
    hits = [f for f in frames if any(n["text"].startswith("-") for n in f["hero_numbers"])]
    if not hits:
        step = max(1, len(frames) // count)
        return frames[::step][:count]
    lo, hi = hits[0]["t"] - 0.5, hits[-1]["t"] + 0.1
    window = [f for f in frames if lo <= f["t"] <= hi] or frames
    chosen = {}
    lives: list[list[dict]] = []
    previous = None
    for f in hits:
        texts = tuple(sorted(n["text"] for n in f["hero_numbers"] if n["text"].startswith("-")))
        if previous is None or texts != previous or f["t"] - lives[-1][-1]["t"] > 0.25:
            lives.append([])
        lives[-1].append(f)
        previous = texts
    for life in lives:
        chosen[life[0]["t"]] = life[0]
        if len(chosen) < count:
            chosen[life[len(life) // 2]["t"]] = life[len(life) // 2]
    slots = count - len(chosen)
    if slots > 0:
        step = (window[-1]["t"] - window[0]["t"]) / max(1, slots + 1)
        for k in range(1, slots + 1):
            target = window[0]["t"] + step * k
            best = min((f for f in window if f["t"] not in chosen), key=lambda f: abs(f["t"] - target), default=None)
            if best:
                chosen[best["t"]] = best
    return [chosen[t] for t in sorted(chosen)][:count]


def compose(capture: Path, out: Path, title: str, count: int, start: float = -1.0, end: float = -1.0, crop: list[int] | None = None, times: list[float] | None = None) -> list[dict]:
    manifest = json.loads((capture / "manifest.json").read_text())
    frames = [f for f in manifest["frames"] if (start < 0 or f["t"] >= start) and (end < 0 or f["t"] <= end)]
    if times:
        chosen = sorted({min(frames, key=lambda f: abs(f["t"] - t))["t"]: min(frames, key=lambda f: abs(f["t"] - t)) for t in times}.values(), key=lambda f: f["t"])
    else:
        chosen = pick(frames, count)
    columns = 4
    thumb = THUMB
    if crop:
        width, height = crop[2] - crop[0], crop[3] - crop[1]
        scale = min(1.0, 960 / width)
        thumb = (int(width * scale), int(height * scale))
        columns = max(1, min(4, 1920 // thumb[0]))
    label_height = LABEL * 2 if crop else LABEL
    rows = (len(chosen) + columns - 1) // columns
    header = 64 if title else 0
    sheet = Image.new("RGB", (thumb[0] * columns, header + rows * (thumb[1] + label_height)), (14, 11, 10))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(str(FONT), 30)
    big = ImageFont.truetype(str(FONT), 38)
    if title:
        draw.text((16, 12), title, fill=(240, 228, 205), font=big)
    t0 = chosen[0]["t"] if chosen else 0.0
    for index, frame in enumerate(chosen):
        x = (index % columns) * thumb[0]
        y = header + (index // columns) * (thumb[1] + label_height)
        image = Image.open(frame["path"]).convert("RGB")
        assert image.size == (1920, 1080), (frame["path"], image.size)
        if crop:
            image = image.crop(tuple(crop))
        sheet.paste(image.resize(thumb, Image.LANCZOS), (x, y + label_height))
        numbers = " ".join(n["text"] + (" [" + n["icon"] + "]" if n["icon"] else "") + (f" ({round(n['progress'] * 100)}% of life)" if crop else "") for n in frame["hero_numbers"])
        banner = frame["banner"][:34]
        label = f"t = {frame['t']:.2f} s   (+{frame['t'] - t0:.2f})   {numbers}"
        draw.text((x + 12, y + 8), label, fill=(246, 220, 160), font=font)
        if banner and not crop:
            width = draw.textlength(banner, font=font)
            draw.text((x + thumb[0] - width - 14, y + 8), banner, fill=(190, 200, 210), font=font)
        if crop:
            rail = frame.get("rail_type") or frame.get("rail") or "nobody"
            acting = frame.get("acting_type") or "-"
            draw.text((x + 12, y + 8 + LABEL), f"rail lights: {rail}   acting: {acting}", fill=(190, 200, 210), font=font)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    return chosen


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--title", default="")
    parser.add_argument("--count", type=int, default=8)
    parser.add_argument("--start", type=float, default=-1.0, help="first capture time (s) to consider")
    parser.add_argument("--end", type=float, default=-1.0, help="last capture time (s) to consider")
    parser.add_argument("--crop", type=int, nargs=4, default=None, metavar=("X0", "Y0", "X1", "Y1"), help="1920x1080 region to keep")
    parser.add_argument("--times", type=float, nargs="+", default=None, help="presentation times to show (nearest frames)")
    args = parser.parse_args()
    chosen = compose(args.capture, args.out, args.title, args.count, args.start, args.end, args.crop, args.times)
    print(args.out)
    for frame in chosen:
        print(f"  {frame['t']:.3f}s {[n['text'] for n in frame['hero_numbers']]} {frame['banner']} {frame['pacing']} ghost {frame['ghost']} rail {frame.get('rail_type', '')}")


if __name__ == "__main__":
    main()
