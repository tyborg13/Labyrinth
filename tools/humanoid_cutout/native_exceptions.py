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


def load(case):
    path = case / 'gate_exceptions.json'
    if not path.exists():
        return frozenset()
    rows = read_json(path)
    if not isinstance(rows, list):
        raise ValueError('gate_exceptions.json must be a list')
    approved = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or set(row) != {'view', 'clip', 'frames', 'rule', 'reason'}:
            raise ValueError('exception %d requires view, clip, frames, rule and reason' % index)
        if row['view'] not in ('front', 'rear') or not isinstance(row['clip'], str) or not row['clip'].strip():
            raise ValueError('exception %d has an invalid view or clip' % index)
        if row['rule'] not in EXCEPTION_RULES:
            raise ValueError('exception %d has an unsupported rule' % index)
        if not isinstance(row['reason'], str) or not row['reason'].strip():
            raise ValueError('exception %d requires a director reason' % index)
        frames = row['frames']
        if (not isinstance(frames, list) or not frames or
                any(type(frame) is not int or frame < 0 for frame in frames)):
            raise ValueError('exception %d requires an exact nonnegative integer frames list' % index)
        for frame in frames:
            key = (row['view'], row['clip'], frame, row['rule'])
            if key in approved:
                raise ValueError('duplicate native gate exception: ' + str(key))
            approved.add(key)
    return frozenset(approved)


def frame_errors(key, metric, new_holes, approved=()):
    """Suppress only a matching view/clip/frame/rule; keep other flags intact."""
    rules = [rule for name, rule in METRIC_RULES.items() if metric[name]]
    if new_holes:
        rules.append(JOINT_HOLE_RULE)
    return [str(key) + ': ' + rule for rule in rules if (*key, rule) not in approved]
