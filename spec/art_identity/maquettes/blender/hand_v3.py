"""Opt-in articulated plate hand (v3): palm, four 3-phalanx fingers, 2-phalanx thumb.

Each phalanx is its own closed faceted prism. It overlaps its predecessor like
a gauntlet lame, so the knuckles read as plate steps, never beads or balls. The
distal phalanx of every digit tapers to a sharp claw apex. Joint points are the
caller's: `curled_points` derives them from knuckle curl angles, and a grip can
supply its own wrap. Pure NumPy; only recipes that import it use it.
"""
import math
import numpy as np
from .faceted_forms import unit, frame, polygon_loft
from .plate_cop import rotate

HAND_DEFAULTS = {'phalanx_sides': 6, 'lame_overlap_widths': .35, 'claw_stations': 3}


def curled_points(knuckle, direction, curl_axis, lengths, curls_degrees):
    """Joint chain from a knuckle: each phalanx turns by its knuckle's curl."""
    points = [np.asarray(knuckle, float)]
    d = unit(direction); total = 0.
    for length, curl in zip(lengths, curls_degrees):
        total += math.radians(curl)
        points.append(points[-1] + rotate(d, curl_axis, total) * length)
    return points


def phalanx(start, end, dorsal, base_width, tip_width, depth_ratio, back, claw=False):
    """One flattened hexagonal prism; `back` extends it under its predecessor."""
    start, end = np.asarray(start, float), np.asarray(end, float)
    side, front, axis = frame(end - start, dorsal)
    sections = []
    def ring(centre, width):
        out = []
        for k in range(HAND_DEFAULTS['phalanx_sides']):
            a = math.tau * k / HAND_DEFAULTS['phalanx_sides']
            out.append((centre + side * width / 2 * math.cos(a) + front * width / 2 * depth_ratio * math.sin(a)).tolist())
        return out
    sections.append(ring(start - axis * back, base_width))
    if claw:
        # The claw ring carries the digit's tip width; beyond it, a sharp apex.
        length = np.linalg.norm(end - start)
        sections.append(ring(start + axis * length * .35, tip_width))
        sections.append([end.tolist()])
    else:
        sections.append(ring(end, tip_width))
    return polygon_loft(sections)


def digit(points, base_width, tip_width, dorsal, depth_ratio=.8):
    """All phalanges of one digit; widths taper linearly to the claw apex.

    `dorsal` is one vector, or one vector per phalanx (a digit wrapping a grip).
    """
    points = [np.asarray(p, float) for p in points]
    lengths = [np.linalg.norm(b - a) for a, b in zip(points, points[1:])]
    dorsals = list(dorsal) if np.ndim(dorsal) == 2 else [dorsal] * len(lengths)
    # Linear taper from the base to the claw ring (35% into the last phalanx).
    total = sum(lengths[:-1]) + .35 * lengths[-1]; widths = [base_width]; run = 0.
    for length in lengths:
        run += length
        widths.append(base_width + (tip_width - base_width) * min(run / total, 1.))
    parts = []
    for k, (a, b) in enumerate(zip(points, points[1:])):
        last = k == len(points) - 2
        back = 0. if k == 0 else HAND_DEFAULTS['lame_overlap_widths'] * widths[k]
        # Successive lames start slightly broader than the end they cover.
        start_width = widths[k] * (1.08 if k else 1.)
        parts.append(phalanx(a, b, dorsals[k], start_width, widths[k + 1], depth_ratio, back, claw=last))
    return parts, widths


def palm(wrist, knuckles, dorsal, thickness, wrist_width):
    """Faceted palm plate from the wrist line to the knuckle line (closed)."""
    knuckles = [np.asarray(k, float) for k in knuckles]
    wrist = np.asarray(wrist, float); dorsal = unit(dorsal)
    across = unit(knuckles[-1] - knuckles[0])
    centre = sum(knuckles) / len(knuckles)
    span = np.linalg.norm(knuckles[-1] - knuckles[0])
    sections = []
    for t, width in [(0., wrist_width), (.55, span * 1.02), (1., span)]:
        c = wrist + (centre - wrist) * t
        h = width / 2
        # Hexagonal plate section: a raised dorsal ridge and flat palm.
        ring = [c - across * h, c - across * h * .55 + dorsal * thickness * .55,
                c + dorsal * thickness * .62, c + across * h * .55 + dorsal * thickness * .55,
                c + across * h, c + across * h * .45 - dorsal * thickness * .4,
                c - across * h * .45 - dorsal * thickness * .4]
        sections.append([p.tolist() for p in ring])
    return polygon_loft(sections)


def cuff(wrist, axis, dorsal, inner_radius, length, flare, thickness):
    """Open-ended flared gauntlet cuff (closed shell) overlapping the vambrace end."""
    wrist = np.asarray(wrist, float)
    side, front, w = frame(axis, dorsal)
    n = 8; outer, inner = [], []
    for t in np.linspace(0, 1, 4):
        c = wrist - w * length * (1 - t)
        r = inner_radius * (1 + flare * (1 - t))
        o, i = [], []
        for k in range(n):
            a = math.tau * k / n + math.pi / 8
            radial = side * math.cos(a) + front * math.sin(a)
            o.append((c + radial * (r + thickness)).tolist()); i.append((c + radial * r).tolist())
        outer.append(o); inner.append(i)
    vertices = [p for row in outer for p in row] + [p for row in inner for p in row]
    count = 4 * n; faces = []
    for r in range(3):
        for c in range(n):
            d = (c + 1) % n
            q = [r * n + c, r * n + d, (r + 1) * n + d, (r + 1) * n + c]
            faces.append(q); faces.append([i + count for i in reversed(q)])
    for ring in (list(range(n)), list(range(3 * n, 4 * n))):
        for c in range(n):
            p, q = ring[c], ring[(c + 1) % n]
            faces.append([p, p + count, q + count, q])
    return vertices, faces, []
