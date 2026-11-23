#!/usr/bin/env python3
"""pla-03 contact sheets: the engine's sentence faces (sentence_face_probe.gd
captures) beside the approved round-5 mocks (mocks_v5/new_faces), cropped with
the mock compositor's crop box so both columns match pixel for pixel in frame.

    python3 tools/pla03/contact_sheet.py CAPTURES_DIR [MOCKS_V5_DIR] [OUT_DIR]

Writes contact_sheet_engine_vs_mock_hover.png, contact_sheet_engine_vs_mock_hand.png,
engine_faces_hand_size_sheet.png and crops/<mode>_<id>.png into OUT_DIR
(default: CAPTURES_DIR/..).
"""
from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ORDER = ["dust_devil", "magma_vent", "discharge", "beacon", "worldroot_stride", "frost_heave", "shatter",
         "cyclone_seal", "squall_shot", "tectonic_maul"]
MOCK_INDEX = {"dust_devil": 1, "magma_vent": 2, "discharge": 3, "beacon": 4, "worldroot_stride": 5, "frost_heave": 7,
              "shatter": 8, "cyclone_seal": 9, "squall_shot": 10, "tectonic_maul": 11}
NAMES = {"dust_devil": "Dust Devil", "magma_vent": "Magma Vent", "discharge": "Discharge", "beacon": "Beacon",
         "worldroot_stride": "Worldroot Stride", "frost_heave": "Frost Heave", "shatter": "Shatter",
         "cyclone_seal": "Cyclone Seal", "squall_shot": "Squall", "tectonic_maul": "Tectonic Maul"}
# Text the owner changed after round 5 (conditions are additive).
CHANGED = {"magma_vent", "frost_heave", "tectonic_maul"}
CROP_MARGIN = (12.0, 20.0, 12.0, 8.0)  # compose_faces.CROP_MARGIN (left, top, right, bottom, local)
BG = (23, 17, 13)
CREAM = (236, 220, 186)
MUTED = (178, 160, 128)
WARN = (232, 128, 96)
FONT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "fonts", "LabyrinthCrumble-UI.ttf")


def label_font(px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT, px)


def crop_box(info: dict) -> tuple[int, int, int, int]:
    s = info["scale"][0]
    ox, oy = info["origin"]
    cx, cy = info["corner"]
    ml, mt, mr, mb = CROP_MARGIN
    return (int(round(ox - ml * s)), int(round(oy - mt * s)), int(round(cx + mr * s)), int(round(cy + mb * s)))


def main() -> int:
    captures = os.path.abspath(sys.argv[1])
    mocks = sys.argv[2] if len(sys.argv) > 2 else "/private/tmp/labyrinth_codex/playability/mocks_v5"
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.dirname(captures)
    os.makedirs(os.path.join(out, "crops"), exist_ok=True)
    manifest = json.load(open(os.path.join(captures, "manifest.json")))
    for mode in ("hover", "hand"):
        pairs = []
        for card_id in ORDER:
            info = manifest[card_id][mode]
            engine = Image.open(os.path.join(captures, "%s_%s.png" % (mode, card_id))).convert("RGB").crop(crop_box(info))
            engine.save(os.path.join(out, "crops", "%s_%s.png" % (mode, card_id)))
            mock_path = os.path.join(mocks, "new_faces", "%02d_%s_%s.png" % (MOCK_INDEX[card_id], card_id, mode))
            mock = Image.open(mock_path).convert("RGB") if os.path.exists(mock_path) else Image.new("RGB", engine.size, BG)
            pad, gap, head, foot = 10, 12, 32, 44
            pair = Image.new("RGB", (pad * 2 + engine.width + gap + mock.width, head + max(engine.height, mock.height) + foot), BG)
            d = ImageDraw.Draw(pair)
            d.text((pad, 7), NAMES[card_id], font=label_font(19), fill=CREAM)
            pair.paste(engine, (pad, head))
            pair.paste(mock, (pad + engine.width + gap, head))
            face = info["face"]
            d.text((pad + 4, head + engine.height + 5), "ENGINE  %d lines, lend %.1f" % (len(face["lines"]), float(face["lend"])),
                   font=label_font(13), fill=MUTED if face["fits"] else WARN)
            d.text((pad + engine.width + gap + 4, head + engine.height + 5), "MOCK v5", font=label_font(13), fill=MUTED)
            if card_id in CHANGED:
                d.text((pad + 4, head + engine.height + 24), "text changed after round 5 (additive condition)", font=label_font(12), fill=WARN)
            pairs.append(pair)
        cols = 2 if mode == "hover" else 3
        cw = max(p.width for p in pairs)
        ch = max(p.height for p in pairs)
        sheet = Image.new("RGB", (cols * cw, 56 + ((len(pairs) + cols - 1) // cols) * ch), BG)
        d = ImageDraw.Draw(sheet)
        title = "pla-03 ENGINE | MOCK v5, %s (1920x1080, 100%% UI, real renderer, cel all)" % (
            "hover" if mode == "hover" else "hand size")
        d.text((16, 12), title, font=label_font(22), fill=CREAM)
        for i, pair in enumerate(pairs):
            sheet.paste(pair, ((i % cols) * cw, 56 + (i // cols) * ch))
        sheet.save(os.path.join(out, "contact_sheet_engine_vs_mock_%s.png" % mode))
    # Engine faces at hand size, 1:1.
    hand = [(card_id, Image.open(os.path.join(out, "crops", "hand_%s.png" % card_id))) for card_id in ORDER]
    hcols = 5
    hw = max(im.width for _, im in hand) + 16
    hh = max(im.height for _, im in hand) + 40
    hs = Image.new("RGB", (hcols * hw + 16, 56 + 2 * hh), BG)
    d = ImageDraw.Draw(hs)
    d.text((16, 12), "pla-03 engine sentence faces at normal hand size (208 px wide, 1:1)", font=label_font(22), fill=CREAM)
    for i, (card_id, im) in enumerate(hand):
        x = 16 + (i % hcols) * hw
        y = 56 + (i // hcols) * hh
        hs.paste(im, (x, y))
        d.text((x + 4, y + im.height + 6), NAMES[card_id], font=label_font(14), fill=MUTED)
    hs.save(os.path.join(out, "engine_faces_hand_size_sheet.png"))
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
