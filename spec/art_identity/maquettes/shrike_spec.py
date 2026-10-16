"""Literal transcription of gust_shrike.py's approved legacy geometry.

This factory supplies the missing source spec (the old export contained only
centroids). Values, labels, joints and tessellation come from that builder.
"""
import math

import numpy as np

from .geometry import grid_mesh, solidify


def legacy_shrike(front_yaw=0):
    labels = {'body': [0.85, 0.15, 0.15], 'head': [0.95, 0.85, 0.1], 'beak': [1, 1, 1], 'mask': [0.1, 0.1, 0.1],
              'wing_near': [1., 0.55, 0.1], 'wing_far': [0.15, 0.35, 0.95], 'tail': [0.85, 0.2, 0.85], 'legs': [0.1, 0.85, 0.85]}
    joints = {'root': [0.12, 0, 0], 'body': [0.12, 0, 0], 'head': [0.58, 0, 1.12],
              'wing_near': [0.32, 0.26, 0.92], 'wing_far': [0.32, -0.26, 0.92], 'tail': [-0.5, 0, 0.36], 'legs': [0.05, 0, 0.42]}
    shapes = []
    def ellipsoid(part, c, s, rot=(0, 0, 0)):
        shapes.append({'type': 'ellipsoid', 'part': part, 'c': c, 's': s, 'rot': rot, 'segments': 32, 'rings': 16})
    def cylinder(a, b, r):
        shapes.append({'type': 'cylinder', 'part': 'legs', 'a': a, 'b': b, 'r': r, 'segments': 12})
    ellipsoid('body', [0, 0, 0.62], [0.66, 0.34, 0.31], [0, math.radians(-32), 0])
    ellipsoid('head', [0.58, 0, 1.12], [0.24, 0.21, 0.21])
    shapes.append({'type': 'cone', 'part': 'beak', 'c': [0.83, 0, 1.06], 'r1': 0.09, 'r2': 0., 'depth': 0.26,
                   'rot': [0, math.radians(105), 0], 'segments': 24})
    ellipsoid('mask', [0.66, 0, 1.16], [0.12, 0.215, 0.06])
    for k in range(-3, 4):
        a = math.radians(k * 11)
        base = np.array([-0.5, 0, 0.36])
        tip = base + [-0.78 * math.cos(a), 0.78 * math.sin(a), -0.34]
        side = np.array([0, 0.07 if abs(k) < 3 else 0.06, 0])
        shapes.append({'type': 'plate', 'part': 'tail', 'pts': [p.tolist() for p in (base - side, base + side, tip + side * 1.8, tip - side * 1.8)], 'thick': 0.03})
    for s in (1, -1):
        cylinder([0.05, s * 0.14, 0.42], [0.12, s * 0.16, 0.0], 0.05)
        for t in (-25, 0, 25):
            a = math.radians(t)
            cylinder([0.12, s * 0.16, 0.02], [0.12 + 0.18 * math.cos(a), s * 0.16 + 0.18 * math.sin(a), -0.02], 0.025)
        cylinder([0.12, s * 0.16, 0.02], [-0.02, s * 0.16, 0.0], 0.022)
    for part, side in [('wing_near', 1), ('wing_far', -1)]:
        rows = []
        n = 16
        for i in range(n + 1):
            t = i / n
            y = side * (0.26 + 0.20 * t)
            lx = 0.32 - 1.05 * t + 0.18 * math.sin(math.pi * t)
            lz = 0.92 + 1.30 * (1 - (1 - t) ** 1.6)
            notch = 0.10 * (1 if int(t * n) % 2 else 0) * t
            tx = -0.32 - 0.41 * t - notch
            tz = 0.58 + 1.64 * t ** 1.4 - notch * 0.6
            cup = side * 0.06 * math.sin(math.pi * t)
            rows.append([[lx, y, lz], [(lx + tx) / 2, y + cup, (lz + tz) / 2], [tx, y, tz]])
        # grid_mesh's diagonal matches the legacy bmesh quad order.
        surface = grid_mesh(rows)
        surface.faces = surface.faces[:, ::-1]
        mesh = solidify(surface, 0.05)
        shapes.append({'type': 'mesh', 'part': part, 'vertices': mesh.vertices.tolist(), 'faces': mesh.faces.tolist()})
    return {'ortho_scale': 3.6, 'target': [0, 0, 0.9], 'camera_distance': 20, 'front_yaw': front_yaw,
            'labels': labels, 'joints': joints, 'shapes': shapes, 'solo': list(labels),
            'part_options': {part: {'smooth_normals': True} for part in ['body', 'head', 'mask']}}
