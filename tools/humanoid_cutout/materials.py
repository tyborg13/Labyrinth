"""Connected hidden surfaces and rr-05 same-material continuations for v2."""
import numpy as np

from maquette_motion.silhouette import components
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import outline_class


def connected_mask(visible, target):
    labels, groups = components(visible | target)
    retained = [label for label, _ in groups if ((labels == label) & visible).any()]
    return target & np.isin(labels, retained)


def clean_continuation(visible, fill, definition, replace_all=False):
    """Discard hidden-only islands; replace outline fragments with own cloth.

    Inputs/previews remain immutable. Only derived continuations change, using
    exact existing non-outline material texels through the rr-05 bleed helper.
    The robe uses painted cloth rather than the old flat maquette fill band.
    """
    result = fill.copy()
    result[~connected_mask(visible[..., 3] > 0, fill[..., 3] > 0)] = 0
    target = result[..., 3] > 0 if replace_all else outline_class(result, definition)
    donors = visible.copy() if replace_all else result.copy()
    donors[visible[..., 3] > 0] = visible[visible[..., 3] > 0]
    replacement = edge_texels(donors, target, definition)
    result[target] = replacement[target]
    return result


def held_depths(depths, view, policy):
    """View-specific body/prop ordering; preserve the inherited body order."""
    result = dict(depths)
    body = [result[name] for name in ('torso', 'sleeve_near', 'sleeve_far', 'robe')]
    if policy[view] == 'behind_body': result['staff'] = min(body) - 1
    elif policy[view] == 'in_front_of_body': result['staff'] = max(body) + 1
    else: raise ValueError('TODO_DESIGN_staff_depth_' + view)
    result['hand_far'] = max(result['hand_far'], result['staff'] + 1)
    return result
