"""Strict rr-12 opaque-component gate on every presented frame.

Unlike the historical silhouette gate's distance allowance, this rejects every
detached component of at most eight pixels, including one-pixel corner flecks.
Native mode reads the actual captured RGBA; offline mode is labelled as such.
"""
import numpy as np
from PIL import Image
from rr12_inputs import VIEWS, read_json
from maquette_motion import silhouette
from humanoid_cutout.native_frames import load_frame

MAX_STRAY_PIXELS = 8  # rr-12 brief, not a tunable allowance.


def small_components(mask):
    return [count for _, count in silhouette.components(mask)[1][1:] if count <= MAX_STRAY_PIXELS]


def report(case, samples, native=None):
    errors, rows = [], []
    manifest = read_json(native / 'frames.json') if native is not None else None
    native_rows = {(r['view'], r['clip'], r['frame']): r for r in manifest['frames']} if manifest else {}
    for view in VIEWS:
        layout = read_json(case / f'layouts/{view}.json')
        images = {p['name']: load_frame(case / p['file']).convert('RGBA') for p in layout['parts']}
        cache = {}
        for row in samples['samples']:
            if row['view'] != view:
                continue
            key = (view, row['clip'], row['frame'])
            signature = tuple((n, tuple(p['transform']), p['alpha']) for n, p in row['parts'].items())
            if native is not None:
                if key not in native_rows:
                    errors.append('/'.join(map(str, key)) + ': missing native frame')
                    continue
                mask = np.asarray(load_frame(native / native_rows[key]['file']).convert('RGBA'))[..., 3] > 0
                sizes = small_components(mask)
            else:
                if signature not in cache:
                    cache[signature] = small_components(silhouette.compose(case, layout, row, images))
                sizes = cache[signature]
            rows.append({'view': view, 'clip': row['clip'], 'frame': row['frame'], 'stray_sizes': sizes})
            if sizes:
                errors.append('/'.join(map(str, key)) + ': detached opaque components <=8px: ' + str(sizes))
    return {'ok': not errors, 'errors': errors, 'native_pixels': native is not None,
            'max_stray_pixels': MAX_STRAY_PIXELS, 'poses': rows}
