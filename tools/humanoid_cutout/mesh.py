"""Source-space two-pixel meshes with the director's exact weight fields."""
import numpy as np

GRID_PX = 2
ROBE_TOP_ROWS_PX = 4
ELBOW_BLEND_HALF_WIDTH_PX = 4


def smoothstep(value):
    value = np.clip(value, 0., 1.)
    return value * value * (3 - 2 * value)


def robe_weights(vertices, bounds):
    left, top, right, bottom = bounds
    points = np.asarray(vertices, dtype=float)
    hem = np.clip((points[:, 1] - top - ROBE_TOP_ROWS_PX) /
                  max(1, bottom - top - ROBE_TOP_ROWS_PX), 0, 1)
    near = smoothstep((points[:, 0] - left - (right - left) / 3) /
                      ((right - left) / 3))
    return {'pelvis': (1 - hem).tolist(), 'hem_near': (hem * near).tolist(),
            'hem_far': (hem * (1 - near)).tolist()}


def sleeve_weights(vertices, shoulder, elbow, wrist, side):
    points = np.asarray(vertices, dtype=float)
    shoulder, elbow, wrist = map(lambda p: np.asarray(p, dtype=float), (shoulder, elbow, wrist))
    upper, fore = elbow - shoulder, wrist - elbow
    # Signed distance along the nearest segment's projected centreline, with
    # zero at the elbow. This follows the bend rather than screen-space y.
    a = np.clip(np.sum((points - shoulder) * upper, axis=1) / np.sum(upper * upper), 0, 1)
    b = np.clip(np.sum((points - elbow) * fore, axis=1) / np.sum(fore * fore), 0, 1)
    da = np.linalg.norm(points - (shoulder + a[:, None] * upper), axis=1)
    db = np.linalg.norm(points - (elbow + b[:, None] * fore), axis=1)
    distance = np.where(da <= db, (a - 1) * np.linalg.norm(upper), b * np.linalg.norm(fore))
    weight = smoothstep((distance + ELBOW_BLEND_HALF_WIDTH_PX) / (2 * ELBOW_BLEND_HALF_WIDTH_PX))
    return {'upper_' + side: (1 - weight).tolist(), 'fore_' + side: weight.tolist()}


def grid(bounds):
    left, top, right, bottom = bounds
    xs = list(range(left, right, GRID_PX)) + [right]
    ys = list(range(top, bottom, GRID_PX)) + [bottom]
    vertices = [[x, y] for y in ys for x in xs]
    triangles = []
    for row in range(len(ys) - 1):
        for column in range(len(xs) - 1):
            a = row * len(xs) + column
            b = a + 1
            c = a + len(xs)
            triangles.extend([[a, b, c], [b, c + 1, c]])
    return vertices, [[x - left, y - top] for x, y in vertices], triangles
