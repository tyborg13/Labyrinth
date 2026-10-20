"""Independent presentation oracle and per-part temporal pixel residual gate."""
import math
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from maquette_motion.gates import expected_bones, bindings_match, unpack
from maquette_motion.raster import nearest_quad, SUBTEXEL_TIE_EPSILON
from maquette_motion import native_ties
from humanoid_cutout.native_frames import load_frame

# Held frames have an exact zero tolerance; at most 1% of a part's occupied pixels
# may show unexplained temporal change at raster boundaries (director, rr-05 fb 9).
PROOF_DEFAULTS = {'fps': 60, 'step_frames': 6, 'canvas_size': 512,
                  'source_offset': 128, 'boundary_residual_fraction': 0.01,
                  'transform_tolerance': 0.0001, 'bounds_margin_px': 2,
                  'native_raster_fraction': 0.01, 'native_raster_edge_pixels': 1}
ROTATION_STEP = math.pi / 120
CANVAS_COLOR_CHANNEL_MAX = 255


def rest_identity(case):
    """Read-only exact RGBA comparison, including every derived underlay."""
    views = {}
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        approved = load_frame(case / layout['rest_source']).convert('RGBA')
        composed = Image.new('RGBA', approved.size)
        for part in sorted(layout['parts'], key=lambda p: p['z_index']):
            composed.alpha_composite(load_frame(case / part['file']).convert('RGBA'), tuple(part['offset']))
        difference = np.any(np.asarray(composed) != np.asarray(approved), axis=2)
        views[view] = {'different_pixels': int(difference.sum()), 'pixel_identical': not difference.any()}
        views[view]['pixel_identical'] = bool(views[view]['pixel_identical'])
    return {'ok': all(row['pixel_identical'] for row in views.values()), 'views': views}


def modulated_alpha(alpha, modulation):
    """Canvas vertex colour is packed to 8 bits before texture sampling.

    In the saved Wisp death/0070 capture, modulation 0.002877542 produces
    zero native alpha. Rounding texture_alpha * modulation invents 13,007
    opaque-mask pixels. Keep the packing separate from framebuffer rounding.
    """
    packed = math.floor(float(np.float32(np.clip(modulation, 0, 1)) * np.float32(CANVAS_COLOR_CHANNEL_MAX)))
    return round_pixels(alpha * (packed / CANVAS_COLOR_CHANNEL_MAX))


def phase_for(definition, phase):
    if not definition.get('loop'):
        return phase
    seconds = definition['seconds']
    held_seconds = math.floor((phase % 1) * seconds * 10 + 1e-8) / 10
    return (held_seconds % seconds) / seconds


def round_pixels(value):
    return np.copysign(np.floor(np.abs(value) + 0.5), value)


def snapped(transform):
    result = transform.copy()
    angle = math.atan2(transform[1, 0], transform[0, 0])
    turn = float(round_pixels(angle / ROTATION_STEP)) * ROTATION_STEP - angle
    c, s = math.cos(turn), math.sin(turn)
    result[:2, :2] = np.array([[c, -s], [s, c]]) @ transform[:2, :2]
    result[:2, 2] = round_pixels(transform[:2, 2])
    return result


def painted(bone, part, layout):
    offset = np.asarray(part['offset']) - layout['joints'][part['bone']]['position']
    local = np.eye(3)
    local[:2, 2] = offset
    return bone @ local


def shared_anchors(layout):
    groups = {}
    for part in layout['parts']:
        groups.setdefault(part['bone'], []).append(part)
    return {bone: next(p for p in layout['parts'] if p['name'] == bone)
            for bone, labels in groups.items() if len(labels) > 1 or any('presentation_anchor' in p for p in labels)}


def presented(bone, part, layout, anchors):
    anchor = anchors.get(part['bone'], part)
    anchor_offset = anchor.get('presentation_anchor', anchor['offset'])
    reference = dict(anchor, offset=anchor_offset)
    relative = np.eye(3)
    relative[:2, 2] = np.asarray(part['offset']) - anchor_offset
    return snapped(painted(bone, reference, layout)) @ relative


def render(image, transform, bounds=None, with_ties=False):
    value = transform.copy()
    value[:2, 2] += PROOF_DEFAULTS['source_offset']
    size = PROOF_DEFAULTS['canvas_size']
    return nearest_quad(image, value, bounds or (0, 0, size, size), with_ties=with_ties)


def changed(first, second):
    # Transparent RGB has no visual significance.
    return np.any(first != second, axis=-1) & ((first[..., 3] > 0) | (second[..., 3] > 0))


def residual(previous, current, ideal_previous, ideal_current):
    observed = changed(previous, current)
    explained = changed(ideal_previous, ideal_current)
    count = int((observed & ~explained).sum())
    area = int(((current[..., 3] > 0) | (previous[..., 3] > 0)).sum())
    return count, count / max(1, area)


def native_frame_matches(actual, expected, samples=None):
    """A quiet blank/frozen surface is not evidence of shimmer-free paint."""
    reference = expected
    if samples is not None:
        # rr-07 feedback 3: invalid ties remain ordinary changed pixels under
        # the existing edge + union-area allowance, including quad coverage
        # rounding. They never become legal source-texel candidates.
        expected, _ = native_ties.select(actual, samples)
    expected_area = int((expected[..., 3] > 0).sum())
    if expected_area and not (actual[..., 3] > 0).any():
        return False
    union = int(((actual[..., 3] > 0) | (reference[..., 3] > 0)).sum())
    allowance = PROOF_DEFAULTS['native_raster_edge_pixels'] + union * PROOF_DEFAULTS['native_raster_fraction']
    return int(changed(actual, expected).sum()) <= allowance


def transform_errors(case, report):
    failures = []
    if not report.get('ok') or not bindings_match(case, report.get('inputs')):
        failures.append('Stale or incomplete pixel samples')
    data = read_json(case / 'compiled_motion.json')
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        anchors = shared_anchors(layout)
        for clip, definition in data['clips'].items():
            rows = [r for r in report['samples'] if r['view'] == view and r['clip'] == clip]
            count = round(definition['seconds'] * 60)
            if len(rows) != count or {r['frame'] for r in rows} != set(range(count)):
                failures.append(f'{view}/{clip}: missing or duplicate 60 Hz poses')
                continue
            for row in rows:
                phase = row['frame'] / (count if definition.get('loop') else count - 1)
                shown = phase_for(definition, phase)
                if abs(row['phase'] - phase) > 1e-8 or abs(row['presented_phase'] - shown) > 1e-8:
                    failures.append(f'{view}/{clip}: presentation clock differs')
                bones = expected_bones(data, layout, view, clip, shown, report['step_distance_px'])
                raw_bones = expected_bones(data, layout, view, clip, phase, report['step_distance_px'])
                if set(row['parts']) != {p['name'] for p in layout['parts']}:
                    failures.append(f'{view}/{clip}: painted part coverage differs')
                    continue
                for part in layout['parts']:
                    actual = row['parts'][part['name']]
                    wanted = presented(bones[part['bone']]['global'], part, layout, anchors)
                    before = painted(raw_bones[part['bone']]['global'], part, layout)
                    observed = unpack(actual['transform'])
                    anchor = anchors.get(part['bone'], part)
                    anchor_observed = unpack(row['parts'][anchor['name']]['transform'])
                    anchor_offset = anchor.get('presentation_anchor', anchor['offset'])
                    anchor_observed[:2, 2] += anchor_observed[:2, :2] @ (np.asarray(anchor_offset) - anchor['offset'])
                    source = painted(bones[part['bone']]['global'], dict(anchor, offset=anchor_offset), layout)
                    # Godot uses float32 transforms. An exact half-pixel may
                    # round either way after matrix cancellation; both nearest
                    # whole pixels are legitimate, never a fractional origin.
                    integer_origin = np.allclose(anchor_observed[:2, 2], round_pixels(anchor_observed[:2, 2]), atol=PROOF_DEFAULTS['transform_tolerance'], rtol=0)
                    nearest_origin = np.all(np.abs(anchor_observed[:2, 2] - source[:2, 2]) <= 0.5 + PROOF_DEFAULTS['transform_tolerance'])
                    attached_origin = anchor_observed[:2, 2] + anchor_observed[:2, :2] @ (np.asarray(part['offset']) - anchor_offset)
                    attached = np.allclose(observed[:2, 2], attached_origin, atol=PROOF_DEFAULTS['transform_tolerance'], rtol=0)
                    if (actual['bone'] != part['bone'] or not integer_origin or not nearest_origin or not attached or not np.allclose(observed[:2, :2], wanted[:2, :2], atol=PROOF_DEFAULTS['transform_tolerance'], rtol=0)
                            or not np.allclose(unpack(actual['before']), before, atol=PROOF_DEFAULTS['transform_tolerance'], rtol=0)):
                        failures.append(f'{view}/{clip}/{part["name"]}: rendered transform differs at {phase}')
    return failures


def shimmer(case, report, native=None):
    """Extra temporal changes beyond canonical source-pixel nearest sampling.

    The caller independently validates every matrix against authored geometry.
    Rasterize that exact validated float32 matrix: re-solving it in float64 can
    cross a subpixel tie and invent shimmer. Cache the ideal for the entire held
    pose, so intra-hold matrix/texture changes still fail with zero tolerance.
    Native proof substitutes isolated GPU part frames for observed images, so
    texture filtering, interpolation and resampling regressions are observable.
    The baseline replays continuous unquantized transforms on the same paint.
    """
    failures, metrics = [], []
    data = read_json(case / 'compiled_motion.json')
    native_rows = {} if native is None else {(r['view'], r['frame'], r['part']): r for r in native['frames']}
    # PixelCapture staged these exact matrices. A separate headless rig can
    # differ by float32 cancellation at its different world origin; near a
    # raster subpixel boundary that changes texel selection. The caller checks
    # native matrices against the independent authored transform oracle first.
    sampled_rows = report['samples'] if native is None else native['samples']
    for view in ('front', 'rear'):
        layout = read_json(case / f'layouts/{view}.json')
        anchors = shared_anchors(layout)
        rows = sorted((r for r in sampled_rows if r['view'] == view and r['clip'] == 'idle'), key=lambda r: r['frame'])
        if not rows:
            failures.append(view + ': missing idle loop')
            continue
        bone_samples = {r['frame']: expected_bones(data, layout, view, 'idle', phase_for(data['clips']['idle'], r['phase']), report['step_distance_px']) for r in rows}
        for part in layout['parts']:
            image = load_frame(case / part['file']).convert('RGBA')
            # One conservative fixed ROI per part and complete loop. This is
            # an acceleration of the same fixed-canvas count, never per-frame
            # fitting or removal of edge pixels from the residual metric.
            corners = np.array([[0, 0, 1], [image.width, 0, 1], [0, image.height, 1], [image.width, image.height, 1]]).T
            transforms = [unpack(r['parts'][part['name']][field]) for r in rows for field in ('before', 'transform')]
            transforms += [presented(bone_samples[r['frame']][part['bone']]['global'], part, layout, anchors) for r in rows]
            points = np.concatenate([(t @ corners)[:2] for t in transforms], axis=1) + PROOF_DEFAULTS['source_offset']
            margin = PROOF_DEFAULTS['bounds_margin_px']
            low = np.maximum(0, np.floor(points.min(axis=1)).astype(int) - margin)
            high = np.minimum(PROOF_DEFAULTS['canvas_size'], np.ceil(points.max(axis=1)).astype(int) + margin)
            bounds = (int(low[0]), int(low[1]), int(high[0]), int(high[1]))
            previous = None
            totals = {kind: {'held_unexplained_pixels': 0, 'boundary_unexplained_pixels': 0,
                             'max_boundary_fraction': 0.0} for kind in ('before', 'after')}
            # Include the wrap from the final sampled pose back to frame zero.
            last_ideal_phase, last_transform = None, None
            ties = {'total': 0, 'max_per_frame': 0, 'max_fraction': 0.0}
            invalid_frames = []
            for ordinal, row in enumerate([rows[-1], *rows]):
                node = row['parts'][part['name']]
                shown = phase_for(data['clips']['idle'], row['phase'])
                bones = bone_samples[row['frame']]
                if shown != last_ideal_phase:
                    candidates = render(image, unpack(node['transform']), bounds, with_ties=True)
                canonical = candidates.default
                ideal = canonical
                last_ideal_phase = shown
                tied = native_ties.statistics(candidates)
                if ordinal:
                    ties['total'] += tied['pixels']
                    ties['max_per_frame'] = max(ties['max_per_frame'], tied['pixels'])
                    ties['max_fraction'] = max(ties['max_fraction'], tied['fraction'])
                if native is None:
                    if node['transform'] != last_transform:
                        actual = render(image, unpack(node['transform']), bounds)
                    last_transform = node['transform']
                    baseline = render(image, unpack(node['before']), bounds)
                else:
                    key = (view, row['frame'], part['name'])
                    if key not in native_rows:
                        failures.append(f'{view}/{part["name"]}: missing native part frame {row["frame"]}')
                        continue
                    entry = native_rows[key]
                    actual = np.asarray(load_frame(native['directory'] / entry['after']).convert('RGBA'))
                    baseline = np.asarray(load_frame(native['directory'] / entry['before']).convert('RGBA'))
                    if actual.shape != (512, 512, 4) or baseline.shape != (512, 512, 4):
                        failures.append('Wrong isolated native part dimensions')
                        continue
                    x, y, right, bottom = bounds
                    # Unexpected native paint beyond the conservative ROI is
                    # also a failure, so a bad transform cannot evade the gate.
                    for value in (actual, baseline):
                        if value[:y, :, 3].any() or value[bottom:, :, 3].any() or value[:, :x, 3].any() or value[:, right:, 3].any():
                            failures.append('Native part escaped its complete-loop bounds')
                    actual = actual[y:bottom, x:right]
                    baseline = baseline[y:bottom, x:right]
                    expected_before = render(image, unpack(node['before']), bounds, with_ties=True)
                    if not native_frame_matches(actual, canonical, candidates) or not native_frame_matches(baseline, expected_before.default, expected_before):
                        failures.append(f'{view}/{part["name"]}/{row["frame"]}: native part does not match its source transform')
                    ideal, invalid_after = native_ties.select(actual, candidates)
                    _, invalid_before = native_ties.select(baseline, expected_before)
                    if ordinal:
                        invalid_frames.append({'frame': row['frame'],
                                               'before': int(invalid_before.sum()),
                                               'after': int(invalid_after.sum())})
                if previous is not None:
                    held = row['presented_phase'] == previous[3]
                    for kind, observed, old in [('before', baseline, previous[0]), ('after', actual, previous[1])]:
                        ideal_previous, ideal_current = native_ties.explanation(previous[2], ideal, held, previous[4], canonical)
                        count, fraction = residual(old, observed, ideal_previous, ideal_current)
                        totals[kind]['held_unexplained_pixels' if held else 'boundary_unexplained_pixels'] += count
                        if not held:
                            totals[kind]['max_boundary_fraction'] = max(totals[kind]['max_boundary_fraction'], fraction)
                        if kind == 'after' and ((held and count) or (not held and fraction > PROOF_DEFAULTS['boundary_residual_fraction'])):
                            failures.append(f'{view}/{part["name"]}/{row["frame"]}: unexplained shimmer ({count}px, {fraction:.6f})')
                previous = (baseline, actual, ideal, row['presented_phase'], canonical)
            invalid_ties = None if native is None else {
                'total': {kind: sum(frame[kind] for frame in invalid_frames) for kind in ('before', 'after')},
                'frames': invalid_frames}
            metrics.append({'view': view, 'part': part['name'], 'ties': ties, 'invalid_ties': invalid_ties, **totals})
    return failures, {'native_pixels': native is not None, 'metric': 'changed RGBA pixels outside the canonical snapped rigid change mask; transparent RGB ignored',
                      'defaults': PROOF_DEFAULTS, 'parts': metrics,
                      'tie_policy': {'epsilon': SUBTEXEL_TIE_EPSILON, 'occupancy_acceptance': 'report-only; legal candidate matches remain exact',
                                     'invalid_ties': 'ordinary changed pixels under the existing native raster allowance; no out-of-range candidate',
                                     'scope': 'presented idle frames, occupied candidate union; wrap comparison not counted twice',
                                     'total': sum(m['ties']['total'] for m in metrics),
                                     'max_per_frame': max((m['ties']['max_per_frame'] for m in metrics), default=0)},
                      'invalid_tie_totals': None if native is None else {
                          kind: sum(m['invalid_ties']['total'][kind] for m in metrics) for kind in ('before', 'after')},
                      'totals': {kind: {field: sum(m[kind][field] for m in metrics) for field in ('held_unexplained_pixels', 'boundary_unexplained_pixels')} for kind in ('before', 'after')}}
