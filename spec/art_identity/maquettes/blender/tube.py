"""Editable hollow loft for measured mouthpieces and flared instrument bells."""
import math

import numpy as np


def tube_mesh(path, radii, wall, sides, radial_profile=None):
    points = np.asarray(path, float)
    if len(points) < 2 or len(radii) != len(points) or sides < 3 or wall <= 0 or min(radii) <= wall:
        raise ValueError('Tube requires matching positive outer radii, wall and at least three sides')
    vertices, faces = [], []
    if radial_profile is not None and (len(radial_profile) != len(points) or
            any(len(row) != sides for row in radial_profile) or
            any(radius * factor <= wall for radius, row in zip(radii, radial_profile) for factor in row)):
        raise ValueError('Gnarled tube profile requires one positive wall-safe factor per ring sample')
    previous = None
    for i, (point, radius) in enumerate(zip(points, radii)):
        direction = points[min(i + 1, len(points) - 1)] - points[max(0, i - 1)]
        if np.linalg.norm(direction) == 0:
            raise ValueError('Tube contains a zero tangent')
        direction /= np.linalg.norm(direction)
        first = np.cross(direction, [0, 0, 1]) if previous is None else previous - direction * np.dot(previous, direction)
        if np.linalg.norm(first) < 1e-10:
            first = np.cross(direction, [0, 1, 0])
        first /= np.linalg.norm(first)
        previous = first
        second = np.cross(direction, first)
        for inner in (False, True):
            for j, angle in enumerate(np.linspace(0, math.tau, sides, endpoint=False)):
                r = radius * (radial_profile[i][j] if radial_profile is not None else 1) - (wall if inner else 0)
                vertices.append((point + r * (first * math.cos(angle) + second * math.sin(angle))).tolist())
    for row in range(len(points) - 1):
        start, end = row * sides * 2, (row + 1) * sides * 2
        for j in range(sides):
            k = (j + 1) % sides
            faces.append([start + j, start + k, end + k, end + j])
            faces.append([start + sides + k, start + sides + j, end + sides + j, end + sides + k])
    for row in (0, len(points) - 1):
        start = row * sides * 2
        for j in range(sides):
            k = (j + 1) % sides
            face = [start + j, start + sides + j, start + sides + k, start + k]
            faces.append(face if row == 0 else face[::-1])
    return vertices, faces
