"""Report outside-mask cut fragments without changing a single owner texel."""
import numpy as np
from PIL import Image
from rr22_case import CASE
from cutout_pipeline.cases import read_json, write_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components


def report():
    result = {}
    for view in ('front', 'rear'):
        layout = read_json(CASE / f'layouts/{view}.json')
        paint = np.asarray(Image.open(CASE / layout['rest_source']).convert('RGBA'))
        source_labels, source_groups = components(paint[..., 3] > 0)
        original = read_json(CASE / f'{view}_baseline/layouts/{view}.json')
        names = [p['logical_part'] for p in original['parts']]
        record = read_json(CASE / f'ownership/{view}.json')
        owners = np.asarray(Image.open(CASE / record['map'])).astype(int) - 1
        fragments = []
        for name in layout['source_labels']:
            if name == 'mortar': continue
            parts = [p for p in layout['parts'] if p['logical_part'] == name]
            visible = source_pixels(CASE, next(p for p in parts if not p.get('hidden_material')))[..., 3] > 0
            labelled, groups = components(visible)
            joined = np.logical_or.reduce([source_pixels(CASE, p)[..., 3] > 0 for p in parts])
            joined_labels, joined_groups = components(joined)
            for label, size in groups[1:]:
                component = labelled == label
                # Other separated anatomical areas are already joined by
                # their covered material. Include tiny visible specks too.
                connected = np.all(joined_labels[component] == joined_groups[0][0])
                if connected and size >= 6: continue
                points = np.argwhere(component)
                fragments.append({'piece': name, 'pixels': size,
                    'bbox': [int(points[:,1].min()), int(points[:,0].min()),
                             int(points[:,1].max())+1, int(points[:,0].max())+1],
                    'source_pixels_xy': points[:, ::-1].tolist(),
                    'native_owners': {n: int((owners[component] == i).sum())
                                      for i, n in enumerate(names) if (owners[component] == i).any()},
                    'connected_by_covered_tuck': bool(connected),
                    'detached_in_approved_painting': bool(not (source_labels[component] == source_groups[0][0]).any())})
        result[view] = fragments
    write_json(CASE / 'proof/mask_fragments.json', result)
    for view, rows in result.items():
        print('RR22 %s OUTSIDE MASK FRAGMENTS: %d pixels; %d components; ownership unchanged' %
              (view.upper(), sum(r['pixels'] for r in rows), len(rows)))
    return result


if __name__ == '__main__': report()
