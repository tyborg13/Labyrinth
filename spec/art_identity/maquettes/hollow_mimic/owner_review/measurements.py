"""Measure actual frozen native triangles; never substitute recipe proxies."""
import numpy as np

from spec.art_identity.maquettes.raster import project, triangle_samples
from spec.art_identity.maquettes.blender.accessory_geometry.forms import pelvis_frame
from .candidate import GATES

MEASURE_DEFAULTS = {'epsilon': 1e-9, 'centre_rows_fraction': .6}
VALIDATION_LIMITS = {'lower_mask_visible_fraction_min': .6, 'crack_band_start': 1 / 3,
                     'crack_band_end': 2 / 3, 'flap_min_contiguous_central_rows': 12}


def depth_image(spec, mesh, view):
    size = GATES['native_size']
    depth = np.full((size, size), -np.inf)
    points = project(spec, mesh['vertices'], view, size)
    for face in mesh['faces']:
        for i in range(1, len(face) - 1):
            triangle = points[[face[0], face[i], face[i + 1]]]
            sample = triangle_samples(triangle, size, size)
            if sample is None:
                continue
            y, x, bary = sample
            z = (bary * triangle[:, 2]).sum(axis=1)
            depth[y, x] = np.maximum(depth[y, x], z)
    if not np.isfinite(depth).any():
        raise ValueError('Native component has no projected pixels')
    return depth


def projected_centre_error(mask, line):
    """Median scanline midpoint over the flap's central rows against its attachment vertical.

    Director (mq-11): in the 3/4 views a flap's top edge follows the belt on a slant and its
    hem is torn, so the end scanlines see one corner or a tatter. The centre line is judged on
    the central fraction of the flap's rows (MEASURE_DEFAULTS['centre_rows_fraction']).
    """
    a, b = np.asarray(line, float)
    if abs(b[1] - a[1]) <= MEASURE_DEFAULTS['epsilon']:
        raise ValueError('Pelvis centre line has no projected height')
    rows = []
    for y in np.flatnonzero(mask.any(axis=1)):
        x = np.flatnonzero(mask[y])
        observed = float((x[0] + x[-1] + 1) / 2)
        expected = float(a[0] + (y + .5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
        rows.append({'y_px': int(y), 'flap_x_px': observed, 'pelvis_x_px': expected,
                     'error_px': observed - expected})
    if not rows:
        raise ValueError('Flap centre line is empty')
    trim = int(len(rows) * (1 - MEASURE_DEFAULTS['centre_rows_fraction']) / 2)
    central = rows[trim:len(rows) - trim] or rows
    if (len(central) < VALIDATION_LIMITS['flap_min_contiguous_central_rows'] or
            any(b['y_px'] != a['y_px'] + 1 for a, b in zip(central, central[1:]))):
        raise ValueError('insufficient flap rows')
    error = float(np.median([row['error_px'] for row in central]))
    return {'passed': abs(error) <= GATES['flap_centre_error_px_max'],
            'median_central_error_px': error, 'central_rows': [central[0]['y_px'], central[-1]['y_px']],
            'maximum_absolute_error_px': max(abs(row['error_px']) for row in rows), 'rows': rows}


def measure(spec, meshes):
    if spec['id'] == 'hollow_mimic':
        design = spec['mq11']['design']
        skull = design['skull']
        rear = project(spec, meshes['hair_crown']['vertices'], 'rear', GATES['native_size'])
        crown, base = project(spec, [skull['crown_m'], skull['base_m']], 'rear', GATES['native_size'])
        height = float(base[1] - crown[1])
        if height <= 0:
            raise ValueError('Measured skull must extend down from its crown in the rear')
        extent = max(0., float(crown[1] - rear[:, 1].min()))
        hair = depth_image(spec, meshes['hair_crown'], 'front')
        mask = depth_image(spec, meshes['cracked_mask'], 'front')
        ys = np.flatnonzero(np.isfinite(mask).any(axis=1))
        top, bottom = int(ys[0]), int(ys[-1]) + 1
        cutoff = top + (bottom - top) * GATES['fringe_mask_top_fraction']
        top_region = np.arange(len(mask))[:, None] + .5 < cutoff
        # A projected overlap behind the mask is not a fringe.
        visible_overlap = np.isfinite(mask) & np.isfinite(hair) & (hair > mask) & top_region
        lower = np.isfinite(mask) & ~top_region
        lower_clear = lower & (~np.isfinite(hair) | (mask > hair))
        lower_fraction = float(lower_clear.sum() / lower.sum())
        crack_start = top + (bottom - top) * VALIDATION_LIMITS['crack_band_start']
        crack_end = top + (bottom - top) * VALIDATION_LIMITS['crack_band_end']
        crack_rows = [int(y) for y in ys if crack_start <= y + .5 < crack_end]
        visible_crack_rows = []
        for y in crack_rows:
            xs = np.flatnonzero(np.isfinite(mask[y]))
            x = int(xs[len(xs) // 2])
            if not np.isfinite(hair[y, x]) or mask[y, x] > hair[y, x]:
                visible_crack_rows.append(y)
        checks = {'rear_height': extent / height <= GATES['rear_height_head_height_max'] * (1 + MEASURE_DEFAULTS['epsilon']),
                  'fringe_over_mask_top': bool(visible_overlap.any()),
                  'lower_mask_remains_visible': lower_fraction >= VALIDATION_LIMITS['lower_mask_visible_fraction_min'],
                  'crack_band_remains_visible': bool(crack_rows) and visible_crack_rows == crack_rows}
        return {'passed': all(checks.values()), 'checks': checks,
                'rear_extent_above_crown_px': extent, 'rear_head_height_px': height,
                'rear_extent_head_height_ratio': extent / height,
                'mask_top_band_px': [top, cutoff],
                'visible_hair_over_mask_top_pixels': int(visible_overlap.sum()),
                'visible_lower_mask_pixels': int(lower_clear.sum()),
                'lower_mask_pixels': int(lower.sum()), 'visible_lower_mask_fraction': lower_fraction,
                'crack_band_px': [crack_start, crack_end], 'crack_rows': crack_rows,
                'visible_crack_rows': visible_crack_rows}
    origin, forward, _, up, _ = pelvis_frame(spec)
    radius = spec['mq11']['design']['belt']['forward_radius_m']
    views = {}
    for view in ('front', 'rear'):
        # Director correction (mq-11 brief): in the 3/4 views the body's front and
        # back midlines project ~25 px off the joint line, so each flap is held to
        # the vertical through its own belt attachment centre instead.
        views[view] = {}
        for name, sign in (('leather_apron', 1), ('rear_leather_apron', -1)):
            anchor = origin + sign * forward * radius
            line = project(spec, [anchor, anchor + up], view, GATES['native_size'])[:, :2]
            views[view][name] = projected_centre_error(np.isfinite(depth_image(spec, meshes[name], view)), line)
    return {'passed': all(row['passed'] for rows in views.values() for row in rows.values()),
            'centre_line': 'vertical through each flap belt attachment centre (pelvis frame)', 'views': views}
