"""Depth-sorted splat preview: real skull + mask from the built blend, plus the candidate hair."""
import json, sys, numpy as np
sys.path.insert(0, "/Users/borgerding/workspace/Labyrinth.worktrees/mq-11")
from PIL import Image, ImageDraw
from spec.art_identity.maquettes.hollow_mimic.owner_review.candidate import compile_candidate
from spec.art_identity.maquettes.raster import project
S = "/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/mq11"
spec = compile_candidate("hollow_mimic"); out = sys.argv[1]
dump = json.load(open(S + "/head_dump.json"))
body = np.array(dump["posed_body"]["head"]); mask = np.array(dump["cracked_mask"]["head"])
hair = next(p for p in spec["pieces"] if p["id"] == "hair_crown")
c, r = np.array(hair["centre"]), np.array(hair["radii"])
g = np.array([[np.cos(t) * np.cos(e), np.sin(t) * np.cos(e), np.sin(e)] for t in np.linspace(0, 6.283, 72) for e in np.linspace(-1.55, 1.55, 36)])
scalp = c + g * r
ppm = 1024 / 2.4
tiles = []
for view in ("front", "rear"):
    im = Image.new("RGB", (1024, 1024), (12, 12, 14)); d = ImageDraw.Draw(im)
    items = [(p[2], 3.5, (120, 104, 96)) for p in project(spec, body, view)]
    items += [(p[2], 3.0, (110, 200, 140)) for p in project(spec, mask, view)]
    items += [(p[2], 4.0, (150, 150, 168)) for p in project(spec, scalp, view)]
    for k, s in enumerate(hair["swept_sections"]):
        P = project(spec, s["path"], view); fr = spec["mq11"]["design"]["tufts"][k]["role"] == "fringe"
        for i in range(len(P) - 1):
            for t in np.linspace(0, 1, 10):
                q = P[i] * (1 - t) + P[i + 1] * t; rad = (s["radii"][i] * (1 - t) + s["radii"][i + 1] * t) * ppm
                items.append((q[2], max(rad, 1.5), (235, 205, 120) if fr else (196, 196, 212)))
    pts = [(p, rad, col) for depth, rad, col in []]
    for depth, rad, col in sorted(((it[0], it[1], it[2]) for it in items), key=lambda x: x[0]):
        pass
    allp = []
    for view_items in [items]:
        pass
    # need screen coords: rebuild with coords
    tiles.append(view)
# second pass with coordinates kept
sheets = []
for view in ("front", "rear"):
    im = Image.new("RGB", (1024, 1024), (12, 12, 14)); d = ImageDraw.Draw(im)
    items = [(p, 3.5, (120, 104, 96)) for p in project(spec, body, view)]
    items += [(p, 3.0, (110, 200, 140)) for p in project(spec, mask, view)]
    items += [(p, 5.0, (150, 150, 168)) for p in project(spec, scalp, view)]
    for k, s in enumerate(hair["swept_sections"]):
        P = project(spec, s["path"], view); fr = spec["mq11"]["design"]["tufts"][k]["role"] == "fringe"
        for i in range(len(P) - 1):
            for t in np.linspace(0, 1, 10):
                q = P[i] * (1 - t) + P[i + 1] * t; rad = (s["radii"][i] * (1 - t) + s["radii"][i + 1] * t) * ppm
                items.append((q, max(rad, 1.5), (235, 205, 120) if fr else (196, 196, 212)))
    for q, rad, col in sorted(items, key=lambda x: x[0][2]):
        d.ellipse((q[0] - rad, q[1] - rad, q[0] + rad, q[1] + rad), fill=col)
    sheets.append(im.crop((330, 40, 694, 460)))
W = Image.new("RGB", (740, 420)); W.paste(sheets[0], (0, 0)); W.paste(sheets[1], (376, 0)); W.resize((1110, 630)).save(out)
