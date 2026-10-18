"""Cylinder lofts, including an open arm socket with one raised mouth band."""
import math

import numpy as np


CYLINDER_DEFAULTS = {'tangent_epsilon': 1e-10}


def cylinder_mesh(start, tip, radius, sides, cap_rings):
    start, tip = np.asarray(start, float), np.asarray(tip, float)
    delta = tip - start
    length = np.linalg.norm(delta)
    if radius <= 0 or length <= radius or sides < 3 or cap_rings < 2:
        raise ValueError('Capped cylinder requires positive radius, length and cap sampling')
    direction = delta / length
    first = np.cross(direction, [0, 0, 1])
    if np.linalg.norm(first) < CYLINDER_DEFAULTS['tangent_epsilon']:
        first = np.cross(direction, [0, 1, 0])
    first /= np.linalg.norm(first)
    second = np.cross(direction, first)
    cap_centre = tip - radius * direction
    rings = [(start, radius), (cap_centre, radius)]
    rings.extend((cap_centre + radius * math.sin(a) * direction, radius * math.cos(a))
                 for a in np.linspace(0, math.pi / 2, cap_rings + 1)[1:-1])
    vertices = [(centre + r * (math.cos(a) * first + math.sin(a) * second)).tolist()
                for centre, r in rings for a in np.linspace(0, math.tau, sides, endpoint=False)]
    faces = [list(reversed(range(sides)))]
    for row in range(len(rings) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            faces.append([row * sides + j, row * sides + k, (row + 1) * sides + k, (row + 1) * sides + j])
    pole = len(vertices)
    vertices.append(tip.tolist())
    last = (len(rings) - 1) * sides
    faces.extend([last + j, last + (j + 1) % sides, pole] for j in range(sides))
    return vertices, faces


def sheath_mesh(start, tip, radius, wall, cap_height, band_height, band_raise, sides, cap_rings):
    """Hollow mouth, annular lip, constant shaft and a closed oblate dome.

    The band is integrated into the outer surface. There is no disk across
    the mouth, no extra band, and no separately owned piece inside the socket.
    """
    start, tip = np.asarray(start, float), np.asarray(tip, float)
    length = np.linalg.norm(tip - start)
    values = [length, radius, wall, cap_height, band_height, band_raise]
    if (not np.isfinite(values).all() or not 0 < wall < min(radius, cap_height) or
            band_height <= 0 or band_raise <= 0 or length <= cap_height + band_height or
            sides < 3 or cap_rings < 2):
        raise ValueError('Open sheath requires wall-safe radius/dome, one positive band and sufficient length')
    direction = (tip - start) / length
    first = np.cross(direction, [0, 0, 1])
    if np.linalg.norm(first) < CYLINDER_DEFAULTS['tangent_epsilon']:
        first = np.cross(direction, [0, 1, 0])
    first /= np.linalg.norm(first)
    second = np.cross(direction, first)
    vertices, faces = [], []

    def ring(distance, r):
        index = len(vertices)
        centre = start + distance * direction
        vertices.extend((centre + r * (math.cos(a) * first + math.sin(a) * second)).tolist()
                        for a in np.linspace(0, math.tau, sides, endpoint=False))
        return index

    def connect(a, b, inside=False):
        for j in range(sides):
            k = (j + 1) % sides
            face = [a + j, a + k, b + k, b + j]
            faces.append(face[::-1] if inside else face)

    cap_base = length - cap_height
    outer = [ring(0, radius + band_raise), ring(band_height, radius + band_raise),
             ring(band_height, radius), ring(cap_base, radius)]
    outer.extend(ring(cap_base + cap_height * math.sin(a), radius * math.cos(a))
                 for a in np.linspace(0, math.pi / 2, cap_rings + 1)[1:-1])
    for a, b in zip(outer, outer[1:]):
        connect(a, b)
    outer_pole = len(vertices)
    vertices.append(tip.tolist())
    faces.extend([outer[-1] + j, outer[-1] + (j + 1) % sides, outer_pole] for j in range(sides))

    inner_radius, inner_height = radius - wall, cap_height - wall
    inner = [ring(0, inner_radius), ring(cap_base, inner_radius)]
    inner.extend(ring(cap_base + inner_height * math.sin(a), inner_radius * math.cos(a))
                 for a in np.linspace(0, math.pi / 2, cap_rings + 1)[1:-1])
    for a, b in zip(inner, inner[1:]):
        connect(a, b, inside=True)
    inner_pole = len(vertices)
    vertices.append((tip - wall * direction).tolist())
    faces.extend([inner[-1] + (j + 1) % sides, inner[-1] + j, inner_pole] for j in range(sides))
    # Annular mouth wall only. Its centre remains empty for the upper arm.
    connect(inner[0], outer[0])
    return vertices, faces
