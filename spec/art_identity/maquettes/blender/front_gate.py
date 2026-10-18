"""Compare front native captures at the design owner's cutout-piece granularity."""
import json
from pathlib import Path

import numpy as np
from PIL import Image


FRONT_GATE_DEFAULTS = {'alpha_threshold': 128}


def rgba(path):
    with Image.open(path) as image:
        return np.array(image.convert('RGBA'))


def displacement_within(before, after, limit):
    """Bidirectional Euclidean silhouette bound, including disappearing pieces."""
    if np.array_equal(before, after):
        return 0
    for radius in range(1, limit + 1):
        def expand(mask):
            padded = np.pad(mask, radius)
            result = np.zeros_like(mask)
            for y in range(-radius, radius + 1):
                for x in range(-radius, radius + 1):
                    if x * x + y * y <= radius * radius:
                        result |= padded[radius + y:radius + y + mask.shape[0],
                                         radius + x:radius + x + mask.shape[1]]
            return result
        if not (before & ~expand(after)).any() and not (after & ~expand(before)).any():
            return radius
    return None


def piece_union(folder, names, view='front'):
    masks = [rgba(Path(folder) / f'{view}_solo_{name}.png')[..., 3] >= FRONT_GATE_DEFAULTS['alpha_threshold']
             for name in names]
    if not masks:
        raise ValueError('An empty piece union cannot certify front preservation')
    return np.logical_or.reduce(masks)


def compare(before, after, contract):
    before, after = Path(before), Path(after)
    old_alpha = rgba(before / 'front_silhouette.png')[..., 3]
    new_alpha = rgba(after / 'front_silhouette.png')[..., 3]
    alpha_changes = int((old_alpha != new_alpha).sum())
    binary_changes = int(((old_alpha >= FRONT_GATE_DEFAULTS['alpha_threshold']) !=
                          (new_alpha >= FRONT_GATE_DEFAULTS['alpha_threshold'])).sum())
    pieces = {}
    for name, labels in contract['pieces'].items():
        old, new = piece_union(before, labels), piece_union(after, labels)
        changed, count = int((old ^ new).sum()), int((old | new).sum())
        displacement = displacement_within(old, new, contract['piece_displacement_px'])
        pieces[name] = {'labels': labels, 'changed_pixels': changed, 'union_pixels': count,
                        'changed_fraction': changed / max(1, count),
                        'displacement_bound_px': displacement,
                        'passed': bool(count and displacement is not None and
                                       changed / count <= contract['piece_changed_fraction'])}
    old_joints = json.loads((before / 'joints_px.json').read_text())['front']
    new_joints = json.loads((after / 'joints_px.json').read_text())['front']
    if set(old_joints) != set(new_joints):
        raise ValueError('Front joint inventory changed')
    joints = {name: float(np.max(abs(np.subtract(point, new_joints[name]))))
              for name, point in old_joints.items()}
    old, new = rgba(before / 'front_clay.png').astype(int), rgba(after / 'front_clay.png').astype(int)
    figure = (old[..., 3] > 0) | (new[..., 3] > 0)
    delta = abs(old[..., :3] - new[..., :3])
    changed = (delta.max(axis=-1) > 0) & figure
    values = delta[changed]
    clay = {'changed_rgb_pixels': int(changed.sum()), 'figure_pixels': int(figure.sum()),
            'max_abs_channel_delta': int(values.max(initial=0)),
            'mean_abs_channel_delta_per_changed_pixel': float(values.mean()) if len(values) else 0.,
            'mean_max_channel_delta_per_changed_pixel': float(values.max(axis=-1).mean()) if len(values) else 0.,
            'gates_delivery': False}
    return {'contract': contract, 'whole_figure_alpha_changed_pixels': alpha_changes,
            'whole_figure_binary_changed_pixels': binary_changes,
            'pieces': pieces, 'joint_displacements_px': joints,
            'max_joint_displacement_px': max(joints.values(), default=0), 'clay': clay,
            'passed': bool(alpha_changes <= contract['whole_alpha_changed_pixels'] and
                           binary_changes == 0 and all(row['passed'] for row in pieces.values()) and
                           max(joints.values(), default=0) <= contract['joint_displacement_px'])}
