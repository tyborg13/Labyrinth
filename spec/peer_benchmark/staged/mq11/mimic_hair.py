"""Director-authored Mimic hair: a mop of 16 uneven tufts on a wider scalp (mq-11 data)."""
import json, math, sys
import numpy as np
sys.path.insert(0, "/Users/borgerding/workspace/Labyrinth.worktrees/mq-11")
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.raster import camera
from spec.art_identity.maquettes.hollow_mimic.batch_proof import ROOT

# Frame measured from the built maquette (blend world == design space for pieces).
dump = json.load(open("/Users/borgerding/workspace/Labyrinth/output/mq11-2026-10-20/head_dump.json"))
body = np.array(dump["posed_body"]["head"]); maskv = np.array(dump["cracked_mask"]["head"])
mc = maskv.mean(0)
head = body[(body[:, 2] > 1.40) & (np.linalg.norm(body[:, :2] - mc[:2], axis=1) < 0.35)]
B = np.array([0.050, -0.015, 1.420])                    # chin/neck on the skull axis
C = head[np.argmax(head[:, 2])].copy()                  # crown vertex
H = float(np.linalg.norm(C - B)); U = (C - B) / H
SK = np.array([0.046, -0.005, 1.660])                   # cranium centre (slice midpoints)
Fw = mc - SK; Fw = Fw - (Fw @ U) * U; Fw /= np.linalg.norm(Fw)     # real face direction
A = np.cross(U, Fw)                                     # cross(A, U) == Fw
side = 1.0
sl = head[np.abs(head[:, 2] - 1.66) < 0.012]
SKULL_W = float(np.ptp(sl @ A))
centre = SK - Fw * 0.11 + U * 0.09
rz = 0.155
target = 1.25 * SKULL_W / 2
r = math.sqrt((target ** 2 - (A[2] * rz) ** 2) / (A[0] ** 2 + A[1] ** 2))
radii = [r, r, rz]

def surf(az, el, frac=0.82):
    """A point inside the scalp: azimuth from Fw toward +A(screen side), elevation from the equator."""
    d = (math.cos(el) * (math.cos(az) * Fw + math.sin(az) * side * A) + math.sin(el) * U)
    # scale to the ellipsoid surface along d, then pull inside by frac
    k = 1 / math.sqrt(sum((d[i] / radii[i]) ** 2 for i in range(3)))
    return centre + d * k * frac, d

def tuft(tid, role, az, el, length, out_az, out_el, bend, r0, bend_to='down'):
    root, n = surf(math.radians(az), math.radians(el))
    a, e = math.radians(out_az), math.radians(out_el)
    direction = math.cos(e) * (math.cos(a) * Fw + math.sin(a) * side * A) + math.sin(e) * U
    direction /= np.linalg.norm(direction)
    L = length * H
    # three segments; the tip bends by `bend` degrees toward -U (gravity) for a hand-cut, uneven look
    pts = [root]
    for i, f in enumerate((0.38, 0.34, 0.28)):
        b = math.radians(bend) * (i / 2)
        g = {'down': U, 'back': Fw}[bend_to]
        d = direction * math.cos(b) - g * math.sin(b)
        pts.append(pts[-1] + d / np.linalg.norm(d) * L * f)
    rad = [r0, r0 * 0.78, r0 * 0.42, r0 * 0.06]
    return {"id": tid, "role": role, "path_m": [p.round(6).tolist() for p in pts], "radii_m": [round(x, 6) for x in rad]}

# (id, role, root azimuth, root elevation, length/H, out azimuth, out elevation, tip bend, base radius)
# azimuth 0 = face (toward camera), +90 = screen right, 180 = back, -90 = screen left (front view).
TUFTS = [
    ("crown_up",      "mop",   165, 72, 0.42,  150, 62, 26, 0.084, "back"),
    ("crown_back",    "mop",   160, 52, 0.50,  160, 60, 22, 0.089, "back"),
    ("back_mid",      "mop",  -165, 34, 0.52, -148, 50, 20, 0.084, "back"),
    ("nape",          "mop",   175,  2, 0.40,  180, -40, 10, 0.076, "down"),
    ("back_low_r",    "mop",   128,  4, 0.44,  112, -12, 16, 0.076, "down"),
    ("back_low_l",    "mop",  -132,  6, 0.42, -116, -10, 16, 0.073, "down"),
    ("side_r_high",   "mop",    98, 44, 0.48,  105, 34, 28, 0.081, "back"),
    ("side_r_low",    "mop",    92, 10, 0.36,   96, -32, 10, 0.068, "down"),
    ("side_l_high",   "mop",  -98, 40, 0.42, -105, 30, 26, 0.078, "back"),
    ("side_l_low",    "mop",   -92,  8, 0.32,  -95, -34, 10, 0.065, "down"),
    ("top_front_r",   "mop",    38, 64, 0.38,   70, 52, 30, 0.076, "back"),
    ("top_front_l",   "mop",   -42, 62, 0.34,  -72, 48, 30, 0.073, "back"),
    ("fringe_c",   "fringe",     6, 40, 0.34,   10, -38,  6, 0.067, "down"),
    ("fringe_r",   "fringe",    32, 36, 0.31,   40, -30,  8, 0.058, "down"),
    ("fringe_l",   "fringe",   -20, 38, 0.33,  -26, -36,  6, 0.060, "down"),
    ("fringe_far", "fringe",   -48, 32, 0.31,  -58, -28,  8, 0.053, "down"),
]
tufts = [tuft(*t) for t in TUFTS]
ear = B + U * 0.20
design = {"skull": {"crown_m": C.round(6).tolist(), "base_m": B.round(6).tolist(), "ear_line_m": ear.round(6).tolist(),
                    "height_m": None, "width_m": SKULL_W, "lateral_axis": None},
          "scalp": {"centre_m": centre.round(6).tolist(), "radii_m": [round(x, 7) for x in radii]},
          "tufts": tufts}
# exact height and unit lateral axis from the rounded points
Cr, Br = np.array(design["skull"]["crown_m"]), np.array(design["skull"]["base_m"])
design["skull"]["height_m"] = float(np.linalg.norm(Cr - Br))
Ur = (Cr - Br) / np.linalg.norm(Cr - Br)
Ar = A - (A @ Ur) * Ur; Ar /= np.linalg.norm(Ar)
design["skull"]["lateral_axis"] = Ar.tolist()
# radii must give scalp width exactly 1.25*SKULL_W along the exact axis
r = math.sqrt((target ** 2 - (Ar[2] * rz) ** 2) / (Ar[0] ** 2 + Ar[1] ** 2))
design["scalp"]["radii_m"] = [r, r, rz]
doc = json.load(open(sys.argv[1])); doc["design"] = design
json.dump(doc, open(sys.argv[1], "w"), indent=2); open(sys.argv[1], "a").write("\n")
print("H", round(H, 4), "skull w", round(SKULL_W, 3), "Fw", Fw.round(3), "A", Ar.round(3), "scalp r", round(r, 4), "centre", centre.round(3))
