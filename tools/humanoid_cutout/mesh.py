"""Source-space two-pixel meshes with the director's exact weight fields."""
import numpy as np

GRID_PX = 2


def smoothstep(value):
    value = np.clip(value, 0., 1.)
    return value * value * (3 - 2 * value)


def robe_weights(vertices, bounds, near_on_right, top_rows_px, bones):
    left, top, right, bottom = bounds
    points = np.asarray(vertices, dtype=float)
    hem = np.clip((points[:, 1] - top - top_rows_px) /
                  max(1, bottom - top - top_rows_px), 0, 1)
    near = smoothstep((points[:, 0] - left - (right - left) / 3) /
                      ((right - left) / 3))
    if not near_on_right: near = 1 - near
    return {bones[0]: (1 - hem).tolist(), bones[1]: (hem * near).tolist(),
            bones[2]: (hem * (1 - near)).tolist()}


def sleeve_weights(vertices, shoulder, elbow, wrist, bones, cuff_rows_px, blend_half_width_px):
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
    weight = smoothstep((distance + blend_half_width_px) / (2 * blend_half_width_px))
    if cuff_rows_px:
        cuff_row = np.sum((points - wrist) * (fore / np.linalg.norm(fore)), axis=1)
        weight[cuff_row >= -cuff_rows_px] = 1.
    return {bones[0]: (1 - weight).tolist(), bones[1]: weight.tolist()}


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


def weights_for(vertices, bounds, joints, recipe):
    """The case selects a field and names its joints; no piece vocabulary here."""
    bones = recipe['bones']
    if recipe['kind'] == 'hem':
        near_right = joints[bones[1]]['position'][0] > joints[bones[2]]['position'][0]
        return robe_weights(vertices, bounds, near_right, recipe['top_rows_px'], bones)
    if recipe['kind'] == 'two_segment':
        return sleeve_weights(vertices, *[joints[n]['position'] for n in recipe['joints']],
                              bones, recipe['cuff_rows_px'], recipe['blend_half_width_px'])
    if recipe['kind'] == 'chain':
        # Cloth follows an authored attachment/mid/tip chain by longitudinal
        # source position, with adjacent weights summing to one.
        start, end = [np.asarray(joints[n]['position']) for n in (bones[0], bones[-1])]
        axis = end - start
        # Elementwise dot avoids platform BLAS dispatch for these tiny rows.
        phase = np.clip(np.sum((np.asarray(vertices) - start) * axis, axis=1) /
                        np.sum(axis * axis), 0, 1) * (len(bones) - 1)
        return {name: np.maximum(0, 1 - np.abs(phase - i)).tolist() for i, name in enumerate(bones)}
    raise ValueError('Unknown mesh field: ' + recipe['kind'])
