"""Inventory and provenance checks for the headless authored/presented sampler."""
from collections import Counter
import math

SAMPLE_FPS = 60


def evidence_errors(data, report, current_bindings, tolerance):
    errors = []
    if report.get('ok') is not True:
        errors.append('bone evidence: sampler did not report ok=true')
    if report.get('errors') != []:
        errors.append('bone evidence: sampler errors must be empty')
    if not current_bindings or report.get('inputs') != current_bindings:
        errors.append('bone evidence: stale input bindings')
    if report.get('compiled_sha256') != current_bindings.get('compiled_motion.json'):
        errors.append('bone evidence: stale compiled motion')
    if report.get('fps') != SAMPLE_FPS:
        errors.append('bone evidence: expected 60 fps inventory')
    rows = report.get('samples')
    if not isinstance(rows, list) or not rows:
        return errors + ['bone evidence: empty sample inventory']
    groups = {}
    for row in rows:
        key = (row.get('view'), row.get('clip'), row.get('kind'))
        if (key[0] not in data['view_tracks'] or key[1] not in data['clips'] or
                key[2] not in ('authored', 'presented') or type(row.get('frame')) is not int or
                not isinstance(row.get('phase'), (int, float)) or not math.isfinite(row['phase'])):
            errors.append('bone evidence: invalid sample inventory row')
            continue
        groups.setdefault(key, []).append(row)
    for view, clips in data['view_tracks'].items():
        for clip, definition in data['clips'].items():
            phases = {0., 1.}
            for track in clips[clip]:
                keys = track['keys']
                for index, key in enumerate(keys):
                    phases.add(key['at'])
                    if index:
                        phases.add((key['at'] + keys[index - 1]['at']) / 2.)
            authored = groups.get((view, clip, 'authored'), [])
            expected = sorted(phases)
            actual = sorted(row['phase'] for row in authored)
            if (len(actual) != len(expected) or any(row['frame'] != -1 for row in authored) or
                    any(abs(a - b) > tolerance for a, b in zip(actual, expected))):
                errors.append('bone evidence: incomplete authored inventory: ' + view + '/' + clip)
            count = math.floor(definition['seconds'] * SAMPLE_FPS + .5)
            presented = groups.get((view, clip, 'presented'), [])
            divisor = count if definition.get('loop', False) else count - 1
            if (Counter(row['frame'] for row in presented) != Counter(range(count)) or
                    any(abs(row['phase'] - row['frame'] / divisor) > tolerance for row in presented)):
                errors.append('bone evidence: incomplete presented inventory: ' + view + '/' + clip)
    return errors
