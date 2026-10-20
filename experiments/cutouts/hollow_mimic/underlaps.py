"""Covered copies of a garment's own approved texels, on its existing field."""
import numpy as np

from case import CASE, read_json
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules


def apply(visible, hidden, view, case=CASE):
    path = case / 'source_underlaps.json'
    if not path.exists(): return
    for name, points in read_json(path).get(view, {}).items():
        target = np.zeros(visible[name].shape[:2], dtype=bool)
        for x, y in points:
            if not visible[name][y, x, 3]:
                raise ValueError('Source underlap must be covered by its own approved paint')
            target[y, x] = True
        # The common garment field stays unchanged. Its covered draw layer
        # carries the same surface across a differently sampled mesh edge.
        continuation = edge_texels(visible[name], target, rules(case, view))
        hidden[name][target] = continuation[target]
