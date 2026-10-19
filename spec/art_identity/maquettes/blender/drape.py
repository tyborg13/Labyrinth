"""Portable tailoring of measured cloth patterns before native simulation.

Only opted-in recipes use this path. Dimensions, hems and gathers are authored
in the figure data; resolution and pinning are explicit, reproducible inputs.
"""
from copy import deepcopy
import math

import numpy as np


DRAPE_DEFAULTS = {'minimum_free_vertices': 4, 'minimum_frames': 8,
                  'implementation_revision': 5, 'length_epsilon': 1e-10,
                  'pin_error_max': 1e-4, 'solver_displacement_min': 1e-6}


def tailor(piece, settings):
    result = deepcopy(piece)
    pattern = result['pattern']
    source = np.array([row['points'] for row in pattern['rows']], float)
    if 'pleat_profile' in settings:
        profile = settings['pleat_profile']
        direction = np.array(settings['pleat_direction'], float)
        direction /= np.linalg.norm(direction)
        if len(profile) != pattern['columns']:
            raise ValueError('Pleat profile must match cloth columns')
        for i, row in enumerate(source):
            row += np.array(profile)[:, None] * direction * i / (len(source) - 1)
    subdivisions = settings['row_subdivisions']
    if not isinstance(subdivisions, int) or subdivisions < 1:
        raise ValueError('Positive integer cloth row_subdivisions required')
    rows = [((1 - u) * a + u * b).tolist()
            for a, b in zip(source, source[1:])
            for u in np.linspace(0, 1, subdivisions, endpoint=False)] + [source[-1].tolist()]
    if settings.get('smooth_rows'):
        rows = []
        for i, (a, b) in enumerate(zip(source, source[1:])):
            before, after = source[max(0, i - 1)], source[min(len(source) - 1, i + 2)]
            for t in np.linspace(0, 1, subdivisions, endpoint=False):
                rows.append(((2*t**3-3*t*t+1)*a + (t**3-2*t*t+t)*(b-before)/2 + (-2*t**3+3*t*t)*b + (t**3-t*t)*(after-a)/2).tolist())
        rows.append(source[-1].tolist())
    columns = pattern['columns']
    pin_rows = settings['pin_rows']
    if not pin_rows or any(not 0 <= i < len(source) for i in pin_rows):
        raise ValueError('Cloth pin_rows must address measured rows')
    pins = [row * subdivisions * columns + j for row in pin_rows for j in range(columns)]
    for start, end in settings.get('pin_filled_spans', []):
        if not 0 <= start < end < len(source):
            raise ValueError('Pinned sewn span must address measured rows')
        pins.extend(i * columns + j for i in range(start * subdivisions, end * subdivisions + 1)
                    for j in range(columns))
    pins = sorted(set(pins))
    if settings.get('pin_upper_rim_count'):
        rim = np.array(rows[-1])
        upper = sorted(range(columns), key=lambda j: (-rim[j, 2], j))[:settings['pin_upper_rim_count']]
        pins.extend((len(rows) - 1) * columns + j for j in upper)
    for source_row in settings.get('pin_opening_rows', []):
        index = source_row * subdivisions
        pins.extend([index * columns, (index + 1) * columns - 1])
    if settings.get('trailing_splits'):
        split = settings['trailing_splits']
        pattern['splits'] = {'from_row': split['source_row'] * subdivisions, 'columns': split['columns'], 'gap_columns': split['gap_columns']}
    pattern.update(rows=[{'points': row} for row in rows], pins=pins)
    for key in ('frames', 'stiffness', 'self_collision', 'solver_margin',
                'collision_margin', 'collision_refine_levels', 'rag', 'thick'):
        if key in settings:
            result[key] = deepcopy(settings[key])
    result['drape'] = deepcopy(settings)
    result['drape']['implementation_revision'] = DRAPE_DEFAULTS['implementation_revision']
    if not simulation_contract(result):
        raise ValueError('Draped cloth requires free fabric and simulation frames')
    return result


def simulation_contract(piece):
    pattern = piece['pattern']
    free = (len(pattern['explicit']['vertices']) if 'explicit' in pattern else pattern['columns'] * len(pattern['rows'])) - len(set(pattern['pins']))
    return (piece['frames'] >= DRAPE_DEFAULTS['minimum_frames'] and
            free >= DRAPE_DEFAULTS['minimum_free_vertices'])


def simulation_valid(piece, report, maximum_displacement):
    return (simulation_contract(piece) and
            DRAPE_DEFAULTS['solver_displacement_min'] < report.get('maximum_solver_displacement', 0) <= maximum_displacement and
            report.get('maximum_free_solver_displacement', 0) > DRAPE_DEFAULTS['solver_displacement_min'] and
            report.get('free_vertices', 0) >= DRAPE_DEFAULTS['minimum_free_vertices'] and
            report.get('maximum_pin_error', float('inf')) <= DRAPE_DEFAULTS['pin_error_max'])


def gathered_rows(rows, closed, profile_px, scale):
    """Authored fold allowance, in source pixels, along each measured row.

    The allowance is continuous across the seam and vanishes at the attachment.
    Native cloth resolves the resulting fabric under gravity and collision.
    """
    result = np.array(rows, float)
    profile = np.array(profile_px, float) * scale
    if len(profile) != len(result[0]):
        if closed:
            profile = np.interp(np.arange(len(result[0])) / len(result[0]),
                                np.arange(len(profile) + 1) / len(profile), np.r_[profile, profile[0]])
        else:
            profile = np.interp(np.linspace(0, 1, len(result[0])), np.linspace(0, 1, len(profile)), profile)
    for i, row in enumerate(result):
        centre = row.mean(axis=0)
        for j, point in enumerate(row):
            radial = point - centre
            radial[2] = 0
            length = np.linalg.norm(radial)
            if length:
                point += radial / length * profile[j] * i / (len(result) - 1)
    return result.tolist()


def path_bands(identifier, part, path, radii, bands, samples):
    """Circular raised bands in the tangent frame of an authored 3D path."""
    from .source_recipe import curve
    points = np.array(path, float)
    distances = np.r_[0, np.cumsum(np.linalg.norm(np.diff(points, axis=0), axis=1))]
    result = []
    for index, band in enumerate(bands):
        position = band['at'] * distances[-1]
        segment = min(len(points) - 2, max(0, np.searchsorted(distances, position) - 1))
        u = (position - distances[segment]) / (distances[segment + 1] - distances[segment])
        centre = (1 - u) * points[segment] + u * points[segment + 1]
        direction = points[segment + 1] - points[segment]
        direction /= np.linalg.norm(direction)
        first = np.cross(direction, [1, 0, 0])
        if np.linalg.norm(first) < DRAPE_DEFAULTS['length_epsilon']:
            first = np.cross(direction, [0, 1, 0])
        first /= np.linalg.norm(first)
        second = np.cross(direction, first)
        radius = (1 - u) * radii[segment] + u * radii[segment + 1]
        if 'width' in band:
            # A raised belt has a flat face and bevelled edges. It is a
            # closed solid, independent of the vessel's ownership/material.
            from .source_recipe import common
            width, relief, edge = band['width'], band['raise'], band['edge']
            if not 0 < edge < min(width / 2, relief) or min(width, relief) <= 0:
                raise ValueError('Raised band requires positive bevel, width and relief')
            profile = [(-width/2, -edge), (-width/2, relief-edge),
                       (-width/2+edge, relief), (width/2-edge, relief),
                       (width/2, relief-edge), (width/2, -edge)]
            vertices = [(centre + direction*z + (radius+out)*
                         (first*math.cos(a)+second*math.sin(a))).tolist()
                        for z,out in profile for a in np.linspace(0,math.tau,samples,endpoint=False)]
            faces = [[j*samples+i, j*samples+(i+1)%samples,
                      ((j+1)%len(profile))*samples+(i+1)%samples,
                      ((j+1)%len(profile))*samples+i]
                     for j in range(len(profile)) for i in range(samples)]
            piece = common(identifier+'_band_'+str(index),'rigid_shell',part)
            piece.update(vertices=vertices, faces=faces, rig_joint=piece['at'])
            result.append(piece)
            continue
        line = [(centre + radius * (first * math.cos(a) + second * math.sin(a))).tolist()
                for a in np.linspace(0, math.tau, samples, endpoint=False)]
        result.append(curve(identifier + '_band_' + str(index), part, line,
                            band['thickness'], [1] * len(line), True))
    return result


def contact_valid(report, fallback_limit):
    """Reject a contact corrector that throws fabric away from its solve."""
    movement = report.get('maximum_contact_displacement', 0)
    limit = report.get('maximum_contact_displacement_allowed', fallback_limit)
    return math.isfinite(movement) and math.isfinite(limit) and 0 <= movement <= limit
