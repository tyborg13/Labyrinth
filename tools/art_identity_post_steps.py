"""Explicit director-authored pixel corrections, after identity processing.

Every correction reads the same pre-step image. RGB means use the pipeline's
nearest-even uint8 quantization; alpha and all unlisted pixels stay unchanged.
"""
import numpy as np
from PIL import Image


def apply(image, recipes, pixel_digest):
    records = []
    for recipe in recipes:
        if (set(recipe) != {'step', 'pixels'} or
                recipe['step'] != 'key_residue_4_neighbour_mean'):
            raise ValueError('unsupported identity correction recipe')
        pixels = recipe['pixels']
        if (not pixels or any(not isinstance(p, list) or len(p) != 2 or
                any(type(v) is not int for v in p) for p in pixels) or
                len(set(map(tuple, pixels))) != len(pixels)):
            raise ValueError('identity correction needs unique integer pixel coordinates')
        source = np.asarray(image.convert('RGBA')).copy()
        output = source.copy()
        corrections = []
        green = lambda p: int(p[1]) > max(int(p[0]), int(p[2]))
        for x, y in pixels:
            if not (0 <= x < image.width and 0 <= y < image.height) or not green(source[y, x]):
                raise ValueError('identity correction target is not green-dominant: ' + str((x, y)))
            neighbours = []
            for u, v in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if 0 <= u < image.width and 0 <= v < image.height and not green(source[v,u]):
                    neighbours.append({'pixel':[u,v], 'rgba':source[v,u].tolist()})
            if not neighbours: raise ValueError('identity correction has no non-green 4-neighbours')
            output[y,x,:3] = np.rint(np.mean([p['rgba'][:3] for p in neighbours], axis=0)).astype(np.uint8)
            corrections.append({'pixel':[x,y], 'before':source[y,x].tolist(),
                'after':output[y,x].tolist(), 'neighbours':neighbours})
        records.append({**recipe, 'pre_step_pixel_sha256':pixel_digest(image),
            'corrections':corrections})
        image = Image.fromarray(output)
    return image, records
