"""Exact leg paint, raw RGB on new native edges, prior production elsewhere."""
from pathlib import Path
import numpy as np
from PIL import Image
from rr37_case import PROJECT, CASE, ASSETS
from rr41_underlay import BASELINE, CLOAKS, inputs, domains, extensions
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels
import rr39_density as arm_density
import rr39_underlay as arm

REPORT = CASE/'proof/rr41_partition.json'


def new_edge_domain(layout=None, logical='cape_near'):
    """The native density rule restores raw RGB on newly exposed alpha edges.

    Removing the duplicate near-cloak backing creates five edge texels whose
    old production RGB differs by one channel level. Later boundary repairs
    use the same rule for either cloak. Values come from
    the unchanged raw cut, not the underlay or a new palette choice.
    """
    from pixel_density import edge_ring
    layout = read_json(CASE/'layouts/front.json') if layout is None else layout
    part = next(p for p in layout['parts'] if p['name']=='hidden_'+logical)
    old = next(p for p in read_json(BASELINE/'source/front.json')['parts'] if p['name']==part['name'])
    current = source_pixels(CASE, part)
    previous = source_pixels(BASELINE/'source', old)
    _, footprint = inputs()
    return edge_ring(current[..., 3]>0) & ~edge_ring(previous[..., 3]>0) & ~footprint


def declarations(layouts):
    result = arm_density.declarations(layouts)
    _, footprint = inputs()
    _, arm_footprint = arm.inputs()
    extra = extensions()
    union = CASE/'uncovered/director_front_footprint.png'
    Image.fromarray((footprint | arm_footprint | extra['cape_far'] | new_edge_domain(layouts['front'],'cape_far')).astype('uint8')*255).save(union)
    near_mask = CASE/'uncovered/director_front_density_edges.png'
    Image.fromarray((footprint | extra['cape_near'] | new_edge_domain(layouts['front'])).astype('uint8')*255).save(near_mask)
    original = read_json(BASELINE/'production/front.json')
    previous = {p['name']:p for p in original['parts']}
    protected = read_json(BASELINE/'baseline.json')['files']
    for part in layouts['front']['parts']:
        if not part.get('hidden_material') or part['logical_part'] not in CLOAKS: continue
        path = union if part['logical_part'] == 'cape_far' else near_mask
        old = previous[part['name']]
        baseline = BASELINE/'production'/old['file']
        expected = protected[str(baseline.relative_to(BASELINE))]
        if digest(baseline) != expected: raise ValueError('Changed rr-41 production baseline: '+part['name'])
        target = ASSETS/'humanoid_v2/front'/Path(part['file']).name
        result[str(target.relative_to(PROJECT))] = {
            'mask':{'path':str(path.relative_to(PROJECT)), 'sha256':digest(path)},
            'source_offset':part['offset'],
            'outside':{'path':str(baseline.relative_to(PROJECT)), 'sha256':expected, 'offset':old['offset']}}
    from rr43_spear import density_declarations
    result.update(density_declarations(layouts['front']))
    from rr43_outline import density_declarations as outline_declarations
    result.update(outline_declarations(layouts))
    return result


def verify():
    paint, footprint = inputs()
    _, arm_footprint = arm.inputs()
    source = read_json(CASE/'layouts/front.json')
    production = read_json(ASSETS/'humanoid_v2/front.json')
    errors = []
    outside = {}
    edge_restorations = []
    actual_domains = {}
    assigned = domains()
    new_edges = {name:new_edge_domain(source,name) for name in CLOAKS}
    extra = extensions()
    for scope, root, layout in (('source', CASE, source), ('production', ASSETS/'humanoid_v2', production)):
        original = read_json(BASELINE/scope/'front.json')
        previous = {p['name']:p for p in original['parts']}
        supplied = np.zeros_like(paint)
        counts = np.zeros(footprint.shape, int)
        outside[scope] = {}
        actual_domains[scope] = {}
        for part in layout['parts']:
            image = source_pixels(root, part)
            baseline = source_pixels(BASELINE/scope, previous[part['name']])
            from rr43_spear import prior_partition, TRANSFER_PARTS
            if part['name'] in TRANSFER_PARTS:
                baseline = prior_partition(scope)[part['name']]
            changed = np.any(image != baseline, axis=-1) & ~footprint
            count = int(changed.sum())
            outside[scope][part['name']] = count
            logical = part['logical_part']
            direct_cloak = part['name']=='hidden_'+logical and logical in CLOAKS
            allowed_edges = new_edges[logical] if scope=='production' and direct_cloak else np.zeros(footprint.shape,bool)
            extension = extra[logical] if direct_cloak else np.zeros(footprint.shape,bool)
            illegal = changed & ~(allowed_edges | extension)
            if illegal.any(): errors.append(f'{scope}/{part["name"]}: {int(illegal.sum())} unapproved changes outside leg footprint')
            if extension.any() and np.any(image[extension] != paint[extension]):
                errors.append(f'{scope}/{part["name"]}: exposure extension differs from protected director paint/air')
            if allowed_edges.any():
                raw_part = next(p for p in source['parts'] if p['name']==part['name'])
                raw = source_pixels(CASE, raw_part)
                if np.any(image[allowed_edges] != raw[allowed_edges]): errors.append('New density edge differs from raw source')
                edge_restorations += [{'part':part['name'],'uv':[int(x),int(y)], 'previous':baseline[y,x].tolist(), 'source':raw[y,x].tolist()}
                    for y,x in np.argwhere(changed & allowed_edges & ~extension)]
            if part['name'] not in ('hidden_'+name for name in CLOAKS):
                if np.any(image != baseline): errors.append(f'{scope}/{part["name"]}: unrelated painted piece changed')
                continue
            # The composite alone cannot prove which cloth owns the paint.
            # Check the complete authority, including zeros on the other cloak.
            authority = footprint & ~arm_footprint
            owned = assigned[part['logical_part']]
            expected_piece = np.zeros_like(paint)
            expected_piece[owned] = paint[owned]
            piece_mismatch = int(np.any(image[authority] != expected_piece[authority], axis=-1).sum())
            actual_domains[scope][part['logical_part']] = int((authority & (image[..., 3] > 0)).sum())
            if piece_mismatch: errors.append(f'{scope}/{part["name"]}: {piece_mismatch} director ownership/RGBA mismatches')
            alpha = footprint & ~arm_footprint & (image[..., 3] > 0)
            supplied[alpha] = image[alpha]
            counts += alpha
        expected = footprint & ~arm_footprint
        mismatch = int(np.any(supplied[expected] != paint[expected], axis=-1).sum())
        if mismatch or np.any(counts > 1): errors.append(f'{scope}: director lining/air mismatch {mismatch}; duplicate paint {int((counts>1).sum())}')
    if not arm_density.verify()['ok']: errors.append('rr-39 director partition/rest regression')
    result = {'ok':not errors, 'errors':errors, 'native_pixels':False,
        'footprint_pixels':int(footprint.sum()), 'opaque_pixels':int((footprint & (paint[..., 3] > 0)).sum()),
        'transparent_pixels':int((footprint & (paint[..., 3] == 0)).sum()),
        'rr39_overlap_pixels':int((footprint & arm_footprint).sum()),
        'domain_pixels':actual_domains['source'],
        'expected_domain_pixels':{name:int(mask.sum()) for name, mask in assigned.items()},
        'actual_domain_pixels':actual_domains,
        'exposure_extension_texels':{name:int(mask.sum()) for name,mask in extra.items()},
        'native_edge_restorations':edge_restorations,
        'per_part_outside_changed_texels':outside}
    write_json(REPORT, result)
    print('RR41 DIRECTOR PARTITION: %s (%d painted; %d air; cape_far=%d cape_near=%d; outside source=%dpx production=%dpx)' % (
        'PASS' if result['ok'] else 'FAIL', result['opaque_pixels'], result['transparent_pixels'],
        result['domain_pixels']['cape_far'], result['domain_pixels']['cape_near'],
        sum(outside['source'].values()), sum(outside['production'].values())))
    print('RR41 NATIVE DENSITY EDGES: %d raw-source restorations outside leg footprint' % len(edge_restorations))
    for error in errors: print(error)
    return result


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seal-rests', action='store_true')
    args = parser.parse_args()
    if not verify()['ok']: raise SystemExit(1)
    if args.seal_rests: arm_density.seal_equivalent_rests(proof_label='rr41')
