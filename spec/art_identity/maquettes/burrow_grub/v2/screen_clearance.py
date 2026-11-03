"""Native-pixel foot clearance against the body at the same screen columns."""
from pathlib import Path
import numpy as np
from PIL import Image

from .recipe import CONSTRAINTS, PROOF_DEFAULTS, LEGS


def alpha(path):
    return np.asarray(Image.open(path).convert('RGBA'))[:, :, 3] >= PROOF_DEFAULTS['screen_alpha_threshold']


def from_masks(body, foot):
    """Use the lowest unoccluded foot pixels, including antialias fringes.

    This is conservative for a partly hidden leg: its true complete foot is
    measured, rather than a higher visible hip fragment. Body is the union of
    non-leg solos, so the leg cannot erase its own comparison silhouette.
    """
    yy, xx = np.nonzero(foot)
    if not len(yy):
        return {'passed': False, 'reason': 'empty foot mask'}
    bottom = int(yy.max())
    columns = xx[yy == bottom]
    samples = []
    for x in columns:
        by = np.flatnonzero(body[:, x])
        if not len(by):
            return {'passed': False, 'reason': 'no body directly above foot', 'foot_x_px': int(x)}
        lower = int(by.max())
        samples.append({'x_px': int(x), 'foot_bottom_y_px': bottom, 'body_bottom_y_px': lower,
                        'below_body_px': max(0, bottom - lower)})
    gap = max(s['below_body_px'] for s in samples)
    return {'below_body_px': gap, 'lowest_pixel_samples': samples,
            'passed': gap <= CONSTRAINTS['foot_screen_clearance_px']}


def measure(directory, spec, coverage):
    directory = Path(directory)
    views = {}
    for view in ('front', 'rear'):
        body = np.logical_or.reduce([alpha(directory / f'{view}_solo_{name}.png')
                                     for name in spec['labels'] if name not in LEGS])
        rows = {}
        for name in LEGS:
            visible = coverage['views'][view][name]['visible_pure_colour_px']
            if visible or (view == 'front' and name.startswith('leg_near_')):
                rows[name] = {**from_masks(body, alpha(directory / f'{view}_solo_{name}.png')),
                              'visible_pure_colour_px': visible}
        views[view] = rows
    checks = {'front_three_near_feet': all(f'leg_near_{i}' in views['front'] and
                  views['front'][f'leg_near_{i}']['passed'] for i in range(1, 4)),
              'all_visible_legs_both_views': all(r['passed'] for rows in views.values() for r in rows.values())}
    return {'basis': 'Native 1024 solo alpha >= 1; body union excludes legs; worst lowest-foot column',
            'maximum_below_body_px': CONSTRAINTS['foot_screen_clearance_px'],
            'views': views, 'checks': checks, 'passed': all(checks.values())}
