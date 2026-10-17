"""Height-normalised source comparisons and deterministic parameter fitting.

Source frame annotations use pixel edges; landmark fractions run from head top
(0) to sole bottom (1). Missing design annotations are disclosed, never guessed
into a passing gate. Fitting only writes a derived specification.
"""
from __future__ import annotations

from copy import deepcopy
import math

import numpy as np
from PIL import Image, ImageDraw

from .geometry import build_meshes, point
from .raster import camera, project, rasterise


FIT_DEFAULTS = {"bands": 24, "normalised_height": 1024, "ground_band_fraction": 0.01,
                "width_ratio_min": 0.6, "width_ratio_max": 1.6,
                "overlay_chart_width": 320, "overlay_padding": 24,
                "green_key_distance": 60, "alpha_threshold": 128, "height_fit_passes": 6, "height_fit_tolerance": 0.001}
GATE_DEFAULTS = {"iou_min": 0.80, "median_band_error_max": 0.12,
                 "max_band_error_max": 0.30, "landmark_error_max": 0.03}


def keyed_mask(image):
    pixels = np.asarray(image.convert('RGBA')).astype(int)
    return (pixels[..., 3] >= FIT_DEFAULTS['alpha_threshold']) & (abs(pixels[..., :3] - [0, 255, 0]).max(-1) > FIT_DEFAULTS['green_key_distance'])


def frame(mask, top_mask=None, annotation=None):
    y, x = np.nonzero(mask)
    if not len(x):
        raise ValueError('Empty figure silhouette')
    top_y = np.nonzero(top_mask)[0].min() if top_mask is not None and top_mask.any() else y.min()
    bottom = float(y.max() + 1)
    band = max(1, math.ceil((bottom - top_y) * FIT_DEFAULTS['ground_band_fraction']))
    ground = float((x[y >= bottom - band] + 0.5).mean())
    result = {'head_top': float(top_y), 'sole_bottom': bottom, 'ground_x': ground}
    if annotation:
        result.update({k: float(annotation[k]) for k in result if isinstance(annotation.get(k), (float, int))})
    if result['sole_bottom'] <= result['head_top']:
        raise ValueError('Source head_top must be above sole_bottom')
    return result


def normalise_points(points, definition):
    p = np.asarray(points, dtype=float)
    return (p - [definition['ground_x'], definition['head_top']]) / (definition['sole_bottom'] - definition['head_top'])


def warp_mask(mask, definition, bounds, height):
    lo, hi = np.array(bounds[0]), np.array(bounds[1])
    size = np.ceil((hi - lo) * height).astype(int)
    scale = height / (definition['sole_bottom'] - definition['head_top'])
    offset = np.array([-definition['ground_x'], -definition['head_top']]) * scale - lo * height
    return np.asarray(Image.fromarray(mask).transform(tuple(size), Image.Transform.AFFINE,
                      (1 / scale, 0, -offset[0] / scale, 0, 1 / scale, -offset[1] / scale),
                      resample=Image.Resampling.NEAREST), dtype=bool)


def width_bands(mask, definition):
    # Width is the mean occupied row span, including gaps inside the outline.
    y, x = np.nonzero(mask)
    fractions = (y + 0.5 - definition['head_top']) / (definition['sole_bottom'] - definition['head_top'])
    bands = np.floor(fractions * FIT_DEFAULTS['bands']).astype(int)
    widths, counts = [], []
    for i in range(FIT_DEFAULTS['bands']):
        rows = np.unique(y[bands == i])
        spans = [x[y == row].max() - x[y == row].min() + 1 for row in rows]
        widths.append(float(np.mean(spans)) / (definition['sole_bottom'] - definition['head_top']) if spans else 0.)
        counts.append(len(rows))
    return np.array(widths), counts


def design_todos(value):
    if isinstance(value, dict):
        return [key for key in value if key.startswith('TODO_DESIGN_')] + [s for item in value.values() for s in design_todos(item)]
    if isinstance(value, list):
        return [s for item in value for s in design_todos(item)]
    return [value] if isinstance(value, str) and value.startswith('TODO_DESIGN_') else []


def measure(spec, source, raster=None, renderer=None):
    if raster is None:
        if spec.get('version') == 2:
            if renderer is None:
                raise ValueError('Spec v2 measurement requires Blender-rendered silhouettes')
            raster = renderer(spec)
        else:
            raster = rasterise(spec)
    settings = spec.get('fit', {})
    source_mask = keyed_mask(source)
    weapon = set(settings.get('weapon_parts', []))
    body = np.zeros_like(raster.silhouette)
    for name, mask in raster.masks.items():
        if name not in weapon:
            body |= mask
    annotation = settings.get('source_frame', {})
    source_frame = frame(source_mask, annotation=annotation)
    maquette_frame = frame(body, raster.masks.get(settings.get('head_part', 'head')))
    frames = [source_frame, maquette_frame]
    masks = [source_mask, raster.silhouette]
    extents = []
    for mask, definition in zip(masks, frames):
        y, x = np.nonzero(mask)
        extents.extend([normalise_points([x.min(), y.min()], definition), normalise_points([x.max() + 1, y.max() + 1], definition)])
    extents = np.array(extents)
    padding = FIT_DEFAULTS['overlay_padding'] / FIT_DEFAULTS['normalised_height']
    bounds = [(extents.min(0) - padding).tolist(), (extents.max(0) + padding).tolist()]
    normalised = [warp_mask(mask, definition, bounds, FIT_DEFAULTS['normalised_height']) for mask, definition in zip(masks, frames)]
    a, b = normalised
    iou = float((a & b).sum() / (a | b).sum())
    sw, _ = width_bands(source_mask, source_frame)
    mw, _ = width_bands(raster.silhouette, maquette_frame)
    _, body_rows = width_bands(body, maquette_frame)
    bands = []
    exclusions = set(settings.get('weapon_only_bands', []))
    for i, (s, m) in enumerate(zip(sw, mw)):
        only_weapon = i in exclusions or (not body_rows[i] and m > 0)
        error = abs(m - s) / s if s else (0. if not m else 1.)
        bands.append({'band': i, 'y_fraction': [(i / 24), ((i + 1) / 24)], 'source_width': float(s),
                      'maquette_width': float(m), 'relative_error': float(error), 'weapon_only': only_weapon})
    landmarks = {}
    unresolved = sorted(set(design_todos(spec)))
    required_frame = ('head_top', 'sole_bottom', 'ground_x')
    if not all(isinstance(annotation.get(k), (int, float)) for k in required_frame):
        unresolved.append('TODO_DESIGN_source_frame (head_top, sole_bottom, ground_x in source pixels)')
    if not settings.get('landmarks'):
        unresolved.append('TODO_DESIGN_landmarks (director-measured source y-fractions and joint names)')
    for name, entry in settings.get('landmarks', {}).items():
        if not isinstance(entry, dict) or not isinstance(entry.get('y'), (float, int)):
            unresolved.append('TODO_DESIGN_landmark_' + name)
            continue
        if not 0 <= entry['y'] <= 1:
            raise ValueError('Landmark fraction outside [0, 1]: ' + name)
        joints = entry.get('joints', [entry.get('joint', name)])
        if not joints or any(joint not in raster.joints for joint in joints):
            raise ValueError('Unknown landmark joints: ' + name)
        actual = float(np.mean([normalise_points(raster.joints[joint], maquette_frame)[1] for joint in joints]))
        landmarks[name] = {'source_y': entry['y'], 'maquette_y': actual, 'absolute_error': abs(actual - entry['y']), 'joints': joints}
    errors = [band['relative_error'] for band in bands if not band['weapon_only']]
    median_error = float(np.median(errors)) if errors else 1.
    gate = {**GATE_DEFAULTS, **settings.get('gate', {})}
    checks = {'iou': iou >= gate['iou_min'], 'median_band_error': bool(errors) and median_error <= gate['median_band_error_max'],
              'max_band_error': max(errors, default=0) <= gate['max_band_error_max'],
              'landmark_error': bool(landmarks) and max(v['absolute_error'] for v in landmarks.values()) <= gate['landmark_error_max'],
              'design_complete': not unresolved}
    report = {'iou': iou, 'median_band_error': median_error, 'max_band_error': float(max(errors, default=0)),
              'bands': bands, 'landmarks': landmarks, 'source_frame': source_frame, 'maquette_frame': maquette_frame,
              'normalisation': 'head-top to sole-bottom; ground-contact centroid aligned',
              'source_frame_annotated': not any('source_frame' in item for item in unresolved),
              'unresolved_design': sorted(set(unresolved)), 'gate': gate, 'checks': {k: bool(v) for k, v in checks.items()},
              'passed': bool(all(checks.values())), 'conflicting_bands': [band['band'] for band in bands if not band['weapon_only'] and band['relative_error'] > gate['max_band_error_max']]}
    overlay = np.zeros((*a.shape, 3), dtype=np.uint8)
    overlay[a] = [0, 255, 255]
    overlay[b] = [255, 0, 255]
    overlay[a & b] = 255
    image = Image.new('RGB', (overlay.shape[1] + FIT_DEFAULTS['overlay_chart_width'], overlay.shape[0]))
    image.paste(Image.fromarray(overlay))
    draw = ImageDraw.Draw(image)
    left = overlay.shape[1]
    draw.text((left + 8, 4), 'cyan: source / magenta: maquette', fill='white')
    draw.text((left + 8, 20), f"IoU {iou:.4f}; gate {'PASS' if report['passed'] else 'FAIL'}", fill='white')
    chart_row_height = 22
    for band in bands:
        y = 50 + band['band'] * chart_row_height
        error = band['relative_error']
        colour = 'gray' if band['weapon_only'] else ('white' if error <= gate['max_band_error_max'] else 'magenta')
        draw.text((left + 8, y), f"{band['band']:02}: {error:.1%}" + (' weapon' if band['weapon_only'] else ''), fill=colour)
        draw.rectangle((left + 125, y + 3, left + 125 + min(error, 1) * 170, y + 12), fill=colour)
    return report, image


def fit_heights(result, report):
    definition = report['maquette_frame']
    size = 1024
    _, _, basis, scale = camera(result)
    height_pixels = definition['sole_bottom'] - definition['head_top']
    landmarks = report['landmarks']
    pairs = sorted([(0., 0.), (1., 1.)] + [(v['maquette_y'], v['source_y']) for v in landmarks.values()])
    old, new = np.array(pairs).T
    if np.any(np.diff(old) <= 1e-8) or np.any(np.diff(new) <= 0):
        raise ValueError('Landmark mapping must be strictly monotonic')
    def warp(p):
        p = np.array(p, dtype=float)
        frac = normalise_points(project(result, p)[:2], definition)[1]
        target = np.interp(frac, old, new)
        p[2] -= (target - frac) * height_pixels * scale / size / basis[1, 2]
        return p.tolist()
    # Joints and free geometry share the same mapping; offsets and dimensions
    # use local endpoint differences, so attached shapes do not move twice.
    original_joints = deepcopy(result['joints'])
    for name, p in original_joints.items():
        result['joints'][name] = warp(p)
    original_shapes = deepcopy(result['shapes'])
    for index, shape in enumerate(result['shapes']):
        centre = point(shape['at'], original_joints) + shape.get('offset', [0, 0, 0]) if 'at' in shape else np.array(shape.get('c', [0, 0, 0]))
        if 'at' in shape:
            shape['offset'] = (np.array(warp(centre)) - result['joints'][shape['at']]).tolist()
        elif 'c' in shape:
            shape['c'] = warp(centre)
        for key in ('a', 'b'):
            if key in shape and not isinstance(shape[key], str):
                shape[key] = warp(shape[key])
        if 'pts' in shape:
            shape['pts'] = [warp(p) for p in shape['pts']]
        if 'vertices' in shape:
            shape['vertices'] = [warp(p) for p in shape['vertices']]
        if 'sections' in shape:
            for section in shape['sections']:
                section['z'] = warp(centre + [0, 0, section['z']])[2] - warp(centre)[2]
        if 's' in shape:
            half = shape['s'][2] * (0.5 if shape['type'] == 'box' else 1)
            if half:
                shape['s'][2] *= (warp(centre + [0, 0, half])[2] - warp(centre - [0, 0, half])[2]) / (2 * half)
        if shape['type'] == 'cloak':
            shape['anchors'] = [p if isinstance(p, str) else warp(p) for p in shape['anchors']]
            top = np.mean([point(p, original_joints) for p in original_shapes[index]['anchors']], axis=0)
            shape['length'] = warp(top)[2] - warp(top - [0, 0, shape['length']])[2]


def fit_spec(spec, source, renderer=None):
    """Warp heights between annotated landmarks, then scale widths per band.

    Shape kinds and part labels survive. Only primitive parameters and joints
    are changed; approved source data and the input spec remain untouched.
    """
    if spec.get('version') == 2:
        return fit_blender_spec(spec, source, renderer)
    result = deepcopy(spec)
    before, _ = measure(result, source)
    if before['unresolved_design']:
        raise ValueError('Fit requires resolved design annotations: ' + '; '.join(before['unresolved_design']))
    if result.get('fit_width_profile'):
        raise ValueError('Fit the original spec, not a previously derived spec_fit.json')
    for _ in range(FIT_DEFAULTS['height_fit_passes']):
        fit_heights(result, before)
        before, _ = measure(result, source)
        if max(v['absolute_error'] for v in before['landmarks'].values()) <= FIT_DEFAULTS['height_fit_tolerance']:
            break
    after_height, _ = measure(result, source)
    bands = after_height['bands']
    ratios = np.array([np.clip(b['source_width'] / b['maquette_width'], FIT_DEFAULTS['width_ratio_min'], FIT_DEFAULTS['width_ratio_max']) if b['maquette_width'] else 1 for b in bands])
    # Per-part band profiles deform along camera-right, preserving depth and
    # the primitive type. The same continuous map moves projected joints.
    result['fit_width_profile'] = {'ratios': ratios.tolist(), 'frame': after_height['maquette_frame'], 'size': 1024, 'parts': {part: ratios.tolist() for part in result['labels']}}
    result['fit_history'] = {'method': 'piecewise landmark heights then clamped band widths', 'ratios': ratios.tolist()}
    return result


def fit_blender_spec(spec, source, renderer):
    """Only joints' Z and transverse bone scales are numerical fit variables.

    Accessories follow the posed joints; their approved patterns, dimensions,
    rotations and simulation settings remain byte-for-byte equivalent data.
    """
    from .blender.contract import BUILD_DEFAULTS, validate
    validate(spec)
    if renderer is None:
        raise ValueError('Spec v2 fitting requires a Blender renderer')
    if spec.get('fit_history'):
        raise ValueError('Fit the original v2 spec, not a previously fitted spec')
    result = deepcopy(spec)
    matrix, _, basis, scale = camera(result)
    if not np.allclose(matrix, np.eye(4)):
        raise ValueError('V2 height fitting requires identity front object transform')
    original = {b['name']: b['scale'][:] for b in result['armature']['bones']}
    history = []
    for _ in range(BUILD_DEFAULTS['fit_passes']):
        raster = renderer(result)
        report, _ = measure(result, source, raster=raster)
        if report['unresolved_design']:
            raise ValueError('Fit requires resolved design: ' + '; '.join(report['unresolved_design']))
        history.append({k: report[k] for k in ('iou', 'median_band_error', 'max_band_error')})
        if report['passed']:
            break
        definition = report['maquette_frame']
        pairs = sorted([(0., 0.), (1., 1.)] + [(v['maquette_y'], v['source_y']) for v in report['landmarks'].values()])
        old, new = np.array(pairs).T
        if np.any(np.diff(old) <= 1e-8) or np.any(np.diff(new) <= 0):
            raise ValueError('Landmark mapping must be strictly monotonic')
        height = definition['sole_bottom'] - definition['head_top']
        size = raster.silhouette.shape[0]
        for name, p in result['joints'].items():
            fraction = normalise_points(raster.joints[name], definition)[1]
            target = np.interp(fraction, old, new)
            p[2] -= (target - fraction) * height * scale / size / basis[1, 2]
        for bone in result['armature']['bones']:
            fractions = [normalise_points(raster.joints[bone[k]], definition)[1] for k in ('head', 'tail')]
            lo, hi = sorted(fractions)
            bands = [b for b in report['bands'] if not b['weapon_only'] and
                     b['maquette_width'] > 0 and lo <= np.mean(b['y_fraction']) <= hi]
            if not bands:
                continue
            ratio = float(np.median([b['source_width'] / b['maquette_width'] for b in bands]))
            for axis in range(2):
                initial = original[bone['name']][axis]
                bone['scale'][axis] = float(np.clip(bone['scale'][axis] * ratio,
                    initial * BUILD_DEFAULTS['fit_scale_min'], initial * BUILD_DEFAULTS['fit_scale_max']))
    result['fit_history'] = {'method': 'Blender silhouettes; joint Z and bone transverse scales only',
                             'passes': history}
    return result

