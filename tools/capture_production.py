"""Real-time production capture assembly and pose/phase equivalence.

Native captures retain the separate exact-inventory comparison. These helpers
never alter capture manifests, pixels, renderer bindings or canonical gates.
"""
from collections import Counter, defaultdict
import heapq
import math
from pathlib import Path

from cutout_pipeline.cases import read_json

MAX_UNMATCHED_PER_CLIP = 2  # Director-approved real-time capture allowance.
PRODUCTION_PHASE_FIELD = 'presented_phase'  # Renderer phase; raw phase is the fallback.
MIN_PHASE_SPAN = .5  # Preserve the existing canonical production progression rule.
PHASE_EPSILON = 1e-6  # Existing canonical contact-phase tolerance.


def capture_views(case):
    return ('front', 'rear') if Path(case).name == 'rr22' else ('front',)


def manifests(case, capture):
    capture = Path(capture)
    if (capture / 'frames.json').is_file():
        return [(capture.name, read_json(capture / 'frames.json'))]
    return [(view, read_json(capture / view / 'frames.json')) for view in capture_views(case)]


def combined(case, capture):
    """Merge ordered view streams without inventing a cross-view restart.

    heapq.merge preserves each source stream's order. A genuine within-view
    restart still reaches the unchanged canonical gate as a descending phase.
    """
    sources = manifests(case, capture)
    data = read_json(Path(case) / 'compiled_motion.json')
    result = dict(sources[0][1], frames=[], walk_samples={}, capture_counts={})
    for view, manifest in sources:
        for key in ('inputs', 'native_pixels', 'size', 'ui_scale'):
            if manifest.get(key) != result.get(key):
                raise ValueError('Production manifests disagree: ' + str(Path(capture) / view / 'frames.json') + ':' + key)
        if manifest.get('ok') is not True or manifest.get('errors'):
            raise ValueError('Capture/manifest error: ' + str(Path(capture) / view / 'frames.json'))
        result['capture_counts'][view] = dict(Counter(row['stage'] for row in manifest['frames']))
        for facing, samples in manifest.get('walk_samples', {}).items():
            if facing in result['walk_samples'] and result['walk_samples'][facing] != samples:
                raise ValueError('Conflicting production walk samples: ' + str(capture) + ':' + facing)
            result['walk_samples'][facing] = samples
        if manifest.get('completions', {}).get('hit', {}).get('clip') != 'idle':
            result['completions'] = manifest.get('completions', {})
    for stage in data['clips']:
        streams = ([dict(row, file=view + '/' + row['file'], capture_view=view)
                    for row in manifest['frames'] if row['stage'] == stage] for view, manifest in sources)
        result['frames'].extend(heapq.merge(*streams, key=lambda row: row['snapshot']['phase']))
    return result


def phase(row, phase_field):
    value = row['snapshot'].get(phase_field, row['snapshot']['phase'])
    if type(value) not in (int, float) or not math.isfinite(value) or not 0 <= value <= 1:
        raise ValueError('Invalid production phase: ' + row['file'])
    return value


def validate_manifest(manifest, data, path):
    """Check the observed progression, never a headless frame-count table."""
    if manifest.get('ok') is not True or manifest.get('errors'):
        raise ValueError('Capture/manifest error: ' + str(path))
    rows = manifest['frames']
    if {row['stage'] for row in rows} != set(data['clips']):
        raise ValueError('Production clip inventory differs: ' + str(path))
    summary = {}
    for clip, definition in data['clips'].items():
        selected = [row for row in rows if row['stage'] == clip]
        phases = [phase(row, 'phase') for row in selected]
        if any(row['snapshot']['clip'] != clip for row in selected):
            raise ValueError('Production clip identity differs: ' + str(path) + ':' + clip)
        if max(phases) - min(phases) < MIN_PHASE_SPAN:
            raise ValueError('Incomplete production phase progression: ' + str(path) + ':' + clip)
        contacts = [definition['contact']] if 'contact' in definition else []
        if any(not any(abs(value - contact) <= PHASE_EPSILON for value in phases) for contact in contacts):
            raise ValueError('Missing production contact phase: ' + str(path) + ':' + clip)
        summary[clip] = {'frames': len(selected), 'phase_min': min(phases), 'phase_max': max(phases),
                         'contacts': contacts, 'sampled_start': any(p == 0 for p in phases),
                         'sampled_end': any(p == 1 for p in phases)}
    return summary


def frame_record(view, row, phase_field):
    return {'view': view, 'stage': row['stage'], 'phase': phase(row, phase_field),
            'file': row['file'], 'pixels_sha256': row.get('pixels_sha256')}


def compare_looping_clip(clip, views, before, after, old, new):
    """Stepped loops may resample poses, but must retain every distinct pose."""
    errors, checks = [], []
    for view in sorted(views):
        left, right = old[(view, clip)], new[(view, clip)]
        a = {row['pixels_sha256'] for row in left if row['pixels_sha256']}
        b = {row['pixels_sha256'] for row in right if row['pixels_sha256']}
        for root, rows in ((before, left), (after, right)):
            if not rows:
                errors.append('No looping production frames: ' + str(root / view) + ':' + clip)
        if a != b:
            errors.append('Looping production pose set differs: ' + str(before / view) + ':' + clip +
                          ' vs ' + str(after / view) + ':' + clip +
                          '; before only: ' + ', '.join(sorted(a - b)) +
                          '; after only: ' + ', '.join(sorted(b - a)))
        checks.append({'view': view, 'frames_before': len(left), 'frames_after': len(right),
                       'poses_before': sorted(a), 'poses_after': sorted(b),
                       'before_only': sorted(a - b), 'after_only': sorted(b - a)})
    return {'clip': clip, 'comparison': 'distinct_pose_hashes', 'views': checks}, errors


def compare_production(case, before, after, *, phase_field):
    errors, checks = [], []
    clips = read_json(Path(case) / 'compiled_motion.json')['clips']
    looping = {clip for clip, definition in clips.items() if definition.get('loop', clip == 'idle') is True}
    sides, loops = [], []
    views = set(capture_views(case))
    for root in (before, after):
        groups, poses = defaultdict(list), defaultdict(list)
        for view, manifest in manifests(case, root):
            views.add(view)
            for row in manifest['frames']:
                record = frame_record(view, row, phase_field)
                if not record['pixels_sha256']:
                    errors.append('Missing production texture hash: ' + str(root / view / row['file']))
                if record['stage'] in looping:
                    poses[(view, record['stage'])].append(record)
                else:
                    groups[(view, record['stage'], record['phase'])].append(record)
        sides.append(groups)
        loops.append(poses)
    old, new = sides
    unmatched = {'before': defaultdict(list), 'after': defaultdict(list)}
    matched = Counter()
    for identity in sorted(old.keys() | new.keys()):
        left, right = old.get(identity, []), new.get(identity, [])
        count = min(len(left), len(right))
        for a, b in zip(left[:count], right[:count]):
            if a['pixels_sha256'] != b['pixels_sha256']:
                errors.append('Renderer texture hash differs: ' + str(before / a['view'] / a['file']) +
                              ' vs ' + str(after / b['view'] / b['file']))
        matched[identity[1]] += count
        unmatched['before'][identity[1]].extend(left[count:])
        unmatched['after'][identity[1]].extend(right[count:])
    for clip in sorted(set(clips) | set(matched)):
        if clip in looping:
            check, failures = compare_looping_clip(clip, views, before, after, *loops)
            checks.append(check)
            errors.extend(failures)
            continue
        a, b = unmatched['before'][clip], unmatched['after'][clip]
        if not matched[clip]: errors.append('No matched production frames: ' + str(before) + ':' + clip)
        for side, rows in (('before', a), ('after', b)):
            if len(rows) > MAX_UNMATCHED_PER_CLIP:
                errors.append(f'{side}/{clip}: {len(rows)} unmatched production frames exceeds {MAX_UNMATCHED_PER_CLIP}: ' +
                              ', '.join(row['view'] + '/' + row['file'] for row in rows))
        checks.append({'clip': clip, 'matched': matched[clip], 'unmatched_before': a, 'unmatched_after': b})
    return {'ok': not errors, 'errors': errors, 'clips': checks,
            'identity': ['view', 'stage', phase_field], 'looping_identity': ['view', 'stage', 'pixels_sha256'],
            'max_unmatched_per_clip_per_side': MAX_UNMATCHED_PER_CLIP}
