"""Independent presentation oracle and per-part temporal pixel residual gate."""
import math
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from maquette_motion.gates import expected_bones, input_bindings, unpack
from maquette_motion.raster import nearest_quad

# Non-player-visible proof defaults. A native boundary may disagree with the model
# on raster edge inclusion, but at most 1% of a part's occupied pixels may have
# unexplained temporal change. Held frames have an exact zero tolerance.
PROOF_DEFAULTS = {'fps': 60, 'step_frames': 6, 'canvas_size': 512,
                  'source_offset': 128, 'boundary_residual_fraction': 0.01,
                  'transform_tolerance': 0.0001, 'bounds_margin_px': 2,
                  'native_raster_fraction': 0.01, 'native_raster_edge_pixels': 1}
ROTATION_STEP = math.pi / 120
CANVAS_COLOR_CHANNEL_MAX = 255


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


def render(image, transform, bounds=None):
    value = transform.copy()
    value[:2, 2] += PROOF_DEFAULTS['source_offset']
    size = PROOF_DEFAULTS['canvas_size']
    return nearest_quad(image, value, bounds or (0, 0, size, size))


def changed(first, second):
    # Transparent RGB has no visual significance.
    return np.any(first != second, axis=-1) & ((first[..., 3] > 0) | (second[..., 3] > 0))


def residual(previous, current, ideal_previous, ideal_current):
    observed = changed(previous, current)
    explained = changed(ideal_previous, ideal_current)
    count = int((observed & ~explained).sum())
    area = int(((current[..., 3] > 0) | (previous[..., 3] > 0)).sum())
    return count, count / max(1, area)


def native_frame_matches(actual, expected):
    """A quiet blank/frozen surface is not evidence of shimmer-free paint."""
    expected_area = int((expected[..., 3] > 0).sum())
    if expected_area and not (actual[..., 3] > 0).any():
        return False
    union = int(((actual[..., 3] > 0) | (expected[..., 3] > 0)).sum())
    allowance = PROOF_DEFAULTS['native_raster_edge_pixels'] + union * PROOF_DEFAULTS['native_raster_fraction']
    return int(changed(actual, expected).sum()) <= allowance


def transform_errors(case, report):
    failures = []
    if not report.get('ok') or report.get('inputs') != input_bindings(case):
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
            image = Image.open(case / part['file']).convert('RGBA')
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
            for row in [rows[-1], *rows]:
                node = row['parts'][part['name']]
                shown = phase_for(data['clips']['idle'], row['phase'])
                bones = bone_samples[row['frame']]
                if shown != last_ideal_phase:
                    ideal = render(image, unpack(node['transform']), bounds)
                last_ideal_phase = shown
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
                    actual = np.asarray(Image.open(native['directory'] / entry['after']).convert('RGBA'))
                    baseline = np.asarray(Image.open(native['directory'] / entry['before']).convert('RGBA'))
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
                    expected_before = render(image, unpack(node['before']), bounds)
                    if not native_frame_matches(actual, ideal) or not native_frame_matches(baseline, expected_before):
                        failures.append(f'{view}/{part["name"]}/{row["frame"]}: native part does not match its source transform')
                if previous is not None:
                    held = row['presented_phase'] == previous[3]
                    for kind, observed, old in [('before', baseline, previous[0]), ('after', actual, previous[1])]:
                        count, fraction = residual(old, observed, previous[2], ideal)
                        totals[kind]['held_unexplained_pixels' if held else 'boundary_unexplained_pixels'] += count
                        if not held:
                            totals[kind]['max_boundary_fraction'] = max(totals[kind]['max_boundary_fraction'], fraction)
                        if kind == 'after' and ((held and count) or (not held and fraction > PROOF_DEFAULTS['boundary_residual_fraction'])):
                            failures.append(f'{view}/{part["name"]}/{row["frame"]}: unexplained shimmer ({count}px, {fraction:.6f})')
                previous = (baseline, actual, ideal, row['presented_phase'])
            metrics.append({'view': view, 'part': part['name'], **totals})
    return failures, {'native_pixels': native is not None, 'metric': 'changed RGBA pixels outside the canonical snapped rigid change mask; transparent RGB ignored',
                      'defaults': PROOF_DEFAULTS, 'parts': metrics,
                      'totals': {kind: {field: sum(m[kind][field] for m in metrics) for field in ('held_unexplained_pixels', 'boundary_unexplained_pixels')} for kind in ('before', 'after')}}
