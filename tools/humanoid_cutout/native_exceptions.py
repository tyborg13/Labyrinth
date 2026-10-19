"""Exact director-reviewed native pixel exceptions, owned by each case."""
from cutout_pipeline.cases import read_json

JOINT_HOLE_RULE = 'new joint-seam hole larger than 1px'
DETACHED_RULE = 'detached opaque component outside outline exemption'
EXCEPTION_RULES = (JOINT_HOLE_RULE, DETACHED_RULE)
METRIC_RULES = {
    'outside_pixels': 'outside own silhouette/tuck',
    'exposed_outline_pixels': 'outline in exposed continuation',
    'dark_slab_blocks': 'exposed dark slab',
    'stray_components': DETACHED_RULE,
    'outline_outside_pixels': 'outline more than 1px outside posed silhouettes',
}


def pocket_signature(pocket):
    if not isinstance(pocket, dict) or set(pocket) != {'bbox', 'pixel_count'}:
        raise ValueError('pocket requires bbox and pixel_count')
    bbox, count = pocket['bbox'], pocket['pixel_count']
    if (not isinstance(bbox, list) or len(bbox) != 4 or
            any(type(n) is not int or n < 0 for n in bbox) or
            bbox[2] <= bbox[0] or bbox[3] <= bbox[1] or
            type(count) is not int or not 1 < count <= (bbox[2] - bbox[0]) * (bbox[3] - bbox[1])):
        raise ValueError('pocket requires nonempty pixel bounds and a valid pixel_count')
    return tuple(bbox), count


def load(case):
    path = case / 'gate_exceptions.json'
    if not path.exists():
        return frozenset()
    rows = read_json(path)
    if not isinstance(rows, list):
        raise ValueError('gate_exceptions.json must be a list')
    approved = set()
    for index, row in enumerate(rows):
        fields = {'view', 'clip', 'frames', 'rule', 'reason'}
        if not isinstance(row, dict) or set(row) not in (fields, fields | {'pocket'}):
            raise ValueError('exception %d requires view, clip, frames, rule and reason' % index)
        if row['view'] not in ('front', 'rear') or not isinstance(row['clip'], str) or not row['clip'].strip():
            raise ValueError('exception %d has an invalid view or clip' % index)
        if row['rule'] not in EXCEPTION_RULES:
            raise ValueError('exception %d has an unsupported rule' % index)
        pocket = None
        if 'pocket' in row:
            if row['rule'] != JOINT_HOLE_RULE:
                raise ValueError('pockets apply only to the joint-hole rule')
            pocket = pocket_signature(row['pocket'])
        if not isinstance(row['reason'], str) or not row['reason'].strip():
            raise ValueError('exception %d requires a director reason' % index)
        frames = row['frames']
        if (not isinstance(frames, list) or not frames or
                any(type(frame) is not int or frame < 0 for frame in frames)):
            raise ValueError('exception %d requires an exact nonnegative integer frames list' % index)
        for frame in frames:
            key = (row['view'], row['clip'], frame, row['rule'])
            if any(entry[:4] == key for entry in approved):
                raise ValueError('duplicate native gate exception: ' + str(key))
            # Retain legacy case exceptions without rewriting other figures.
            # New pocket entries never create a frame-wide exemption.
            approved.add((*key, pocket) if pocket is not None else key)
    return frozenset(approved)


def frame_errors(key, metric, new_holes, approved=()):
    """Consume each exact pocket once; unmatched holes keep the rule failing."""
    rules = [rule for name, rule in METRIC_RULES.items() if metric[name]]
    remaining = set(approved)
    for hole in new_holes:
        try:
            exact = (*key, JOINT_HOLE_RULE, pocket_signature(hole)) if isinstance(hole, dict) else None
        except ValueError:
            exact = None  # Malformed observed evidence never earns an exception.
        if exact in remaining:
            remaining.remove(exact)
        else:
            rules.append(JOINT_HOLE_RULE)
            break
    return [str(key) + ': ' + rule for rule in rules if (*key, rule) not in approved]
