"""Reproduce the director-approved partitions and item-only hidden fills."""
import numpy as np
from PIL import Image
from config import ROOT, case, baseline_case, read_json, digest
from partition import images_for, seer_rear
from fills import chain_arc, shaft


def masks_for(rig, view):
    root = baseline_case(rig)
    layout = read_json(root / f'layouts/{view}.json')
    return images_for(root, dict(layout, parts=[
        dict(p, file=layout['proof_layers'][p['name']]['mask']) for p in layout['parts']]))


def released(rig, view, root, layout):
    images, classifications = images_for(root, layout), masks_for(rig, view)
    changed, checks, records = {}, {}, []
    region = 'chain_top_arc' if rig == 'chainbound_gaoler' else 'staff_under_palm'
    if rig == 'hoarfrost_seer' and view != 'rear': return changed, checks, records
    request = case(rig) / f'underlay_requests/{view}_{region}.png'
    mask = np.asarray(Image.open(request).convert('L')) > 0
    if rig == 'chainbound_gaoler':
        name = 'chain'
        changed[name], checks[name], record = chain_arc(view, images[name], classifications[name], mask)
    else:
        name = 'staff'
        changed, palm = seer_rear(images)
        if not np.array_equal(mask, palm): raise ValueError('Changed approved palm request mask')
        checks = {n: classifications[n].copy() for n in changed}
        checks['hand_far'][palm] = classifications['staff'][palm]
        checks['staff'][palm] = 0
        changed[name], checks[name], record = shaft(changed[name], checks[name], mask)
    source = root / next(p for p in layout['parts'] if p['name'] == name)['file']
    record.update(view=view, region=region, source_file=str(source.relative_to(ROOT)), source_sha256=digest(source),
                  request_mask_sha256=digest(request), copied_pixels=len(record['texels']))
    record['rgba'] = [images[name][v, u].tolist() for _, _, u, v in record['texels']]
    records.append(record)
    return changed, checks, records
