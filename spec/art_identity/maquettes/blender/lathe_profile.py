"""Smooth a measured curved horn axis; radius controls remain interpolating."""
import numpy as np

LATHE_DEFAULTS = {'axis_subdivisions': 8}


def smooth_axis(points, radii, subdivisions=8):
    points = np.array(points, float)
    if len(points) != len(radii) or len(points) < 2:
        raise ValueError('Lathe axis and profile controls must correspond')
    dense, profile = [], []
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        before, after = points[max(0, i - 1)], points[min(len(points) - 1, i + 2)]
        for t in np.linspace(0, 1, subdivisions, endpoint=False):
            dense.append(((2*t**3-3*t*t+1)*a + (t**3-2*t*t+t)*(b-before)/2 +
                          (-2*t**3+3*t*t)*b + (t**3-t*t)*(after-a)/2).tolist())
            profile.append((1 - t) * radii[i] + t * radii[i + 1])
    return dense + [points[-1].tolist()], profile + [radii[-1]]
