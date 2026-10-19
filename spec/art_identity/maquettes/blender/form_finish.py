"""Opt-in corrective sculpt on the real weighted CC0 skin, before unposing.

Fairing removes skin microanatomy under a suit; radial scaling retains joints.
The spiral is shallow continuous relief, never a replacement primitive limb.
"""
import numpy as np

FORM_DEFAULTS = {'epsilon': 1e-9}


def finish(points, faces, totals, bones, joints, config):
    points = np.asarray(points, float)
    result = points.copy()
    for region in config.get('fair_regions', []):
        from .source_cage import relax_offsets
        weights = np.array([v.get(region, 0.) for v in totals])
        mask = weights > FORM_DEFAULTS['epsilon']
        smooth = relax_offsets(points, faces, mask, config['fair_iterations'], config['fair_factor'])
        # Preserve cross-section volume around the region's centroid.
        centre = np.average(points[mask], axis=0, weights=weights[mask])
        old = np.average(np.sum((points[mask]-centre)**2, axis=1), weights=weights[mask])
        new = np.average(np.sum((smooth[mask]-centre)**2, axis=1), weights=weights[mask])
        smooth[mask] = centre + (smooth[mask]-centre) * np.sqrt(old/max(new, FORM_DEFAULTS['epsilon']))
        result += (smooth-points)*weights[:, None]
    base = result.copy()
    for region, scale in config.get('radial_scales', {}).items():
        bone = next(b for b in bones if b['region'] == region)
        a, b = (np.array(joints[bone[key]]) for key in ('head', 'tail'))
        axis = (b-a)/np.linalg.norm(b-a)
        radial = base-a-((base-a)@axis)[:, None]*axis
        weights = np.array([v.get(region, 0.) for v in totals])
        result += radial*(scale-1)*weights[:, None]
    for region, scale in config.get('length_scales', {}).items():
        bone=next(b for b in bones if b['region']==region)
        a,b=(np.array(joints[bone[key]]) for key in ('head','tail'))
        axis=(b-a)/np.linalg.norm(b-a)
        weights=np.array([v.get(region,0.) for v in totals])
        result+=((base-a)@axis)[:,None]*axis*(scale-1)*weights[:,None]
    for region, sculpt in config.get('spirals', {}).items():
        bone = next(b for b in bones if b['region'] == region)
        a, b = (np.array(joints[bone[key]]) for key in ('head', 'tail'))
        axis = (b-a)/np.linalg.norm(b-a)
        u = np.cross(axis, np.eye(3)[np.argmin(abs(axis))]);u /= np.linalg.norm(u)
        v = np.cross(axis, u)
        q = result-a; t = (q@axis)/np.linalg.norm(b-a)
        angle = np.arctan2(q@v,q@u)
        radial = q-(q@axis)[:,None]*axis
        normals = radial/np.maximum(np.linalg.norm(radial,axis=1)[:,None],FORM_DEFAULTS['epsilon'])
        amount = sculpt['depth_m']*np.cos(sculpt['strands']*(angle-t*np.pi*2*sculpt['turns']))
        weights = np.array([p.get(region,0.) for p in totals])
        result += normals*amount[:,None]*weights[:,None]
    return result


def validate(config, regions):
    import math
    named=set(config.get('fair_regions',[])) | set(config.get('radial_scales',{})) | set(config.get('length_scales',{})) | set(config.get('spirals',{}))
    if not named <= set(regions):
        raise ValueError('Form finish names an unknown anatomical region')
    if config.get('fair_regions') and (type(config['fair_iterations']) is not int or not 0 <= config['fair_iterations'] <= 64 or not 0 <= config['fair_factor'] <= 1):
        raise ValueError('Form fairing requires bounded iterations and factor')
    for key in ('radial_scales','length_scales'):
        if any(not math.isfinite(v) or v <= 0 for v in config.get(key,{}).values()):
            raise ValueError('Form scales must be positive finite values')
    for sculpt in config.get('spirals',{}).values():
        if not (sculpt['depth_m'] > 0 and sculpt['turns'] > 0 and type(sculpt['strands']) is int and sculpt['strands'] > 0):
            raise ValueError('Root relief requires positive depth, turns and integral strands')
