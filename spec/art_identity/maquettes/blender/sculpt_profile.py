"""Recipe-driven organic folds and dense stone relief, independent of Blender.

These fields describe modelled surfaces. They never affect lights, materials,
camera, ownership or the legacy cloth figures' geometry.
"""
import math

from .surface_relief import relief_weight, value_noise

PROFILE_DEFAULTS = {'seed_subdivisions': 5, 'epsilon': 1e-10}


def deform(point, radii, profile):
    q = [v / radius for v, radius in zip(point, radii)]
    phase = profile['phase']
    asymmetry = profile['asymmetry']
    scale = 1 + asymmetry[0] * math.sin(3*q[1]+phase) + asymmetry[1] * math.sin(4*q[2]-phase)
    result = [v * scale for v in point]
    result[1] += radii[1] * asymmetry[2] * math.sin(3*q[0]+phase)
    if 'underside' in profile and q[2] < profile['underside']['start']:
        floor = profile['underside']
        result[2] = radii[2] * (floor['start'] + (q[2]-floor['start'])*floor['compression'])
    if 'top_plate' in profile and q[2] > profile['top_plate']['start']:
        plate = profile['top_plate']
        result[2] = radii[2] * (plate['start'] + (q[2]-plate['start'])*plate['compression'])
    if 'folds' in profile:
        folds = profile['folds']
        angle = math.atan2(q[2], q[1])
        crease = max(0, (abs(q[0])-folds['crease_start'])/(1-folds['crease_start']))
        amount = folds['amplitude'] * (0.25+0.75*crease) * math.sin(
            folds['frequency']*q[0]+1.6*math.sin(3*angle+phase)+phase)
        length = max(math.hypot(q[1], q[2]), PROFILE_DEFAULTS['epsilon'])
        result[1] += amount * q[1]/length
        result[2] += amount * q[2]/length
    if 'rim' in profile:
        rim = profile['rim']
        amount = rim['height'] * math.exp(-((q[2]-rim['z'])/rim['width'])**2)
        length = max(math.hypot(q[0], q[1]), PROFILE_DEFAULTS['epsilon'])
        result[0] += amount * q[0]/length
        result[1] += amount * q[1]/length
    return result


def sculpt_weight(point, relief, profile):
    value = relief_weight(point, relief['scale'], relief['depth'])
    value = max(0, min(1, (value-.5)*profile['relief_contrast']+.5))
    if 'pitting' in profile:
        pits = profile['pitting']
        # Ridged noise makes shallow cup-shaped depressions, rather than
        # asking a low-resolution group to interpolate smooth broad blobs.
        fine = value_noise([v/pits['scale'] + profile['phase'] for v in point])
        cup = max(0, 1-abs(fine-.42)/.16)**2
        value = max(0, min(1, value-pits['amount']*cup))
    return value


def validate_profile(profile):
    from .contract import vector
    vector(profile['asymmetry'], 3, 'surface asymmetry')
    if 'seed_subdivisions' in profile and (type(profile['seed_subdivisions']) is not int or not 4 <= profile['seed_subdivisions'] <= 6):
        raise ValueError('Sculpt seed requires bounded dense uniform sampling')
    if not math.isfinite(profile['phase']) or not 0 < profile['relief_contrast'] <= 10:
        raise ValueError('Sculpt profile requires finite phase and positive relief contrast')
    if any(abs(value) > .25 for value in profile['asymmetry']):
        raise ValueError('Surface asymmetry exceeds the fitted mass')
    for key in ('underside', 'top_plate'):
        if key in profile and not (0 < profile[key]['compression'] <= 1 and -1 < profile[key]['start'] < 1):
            raise ValueError('Sculpted cap requires a bounded compression')
    if 'pitting' in profile and not (profile['pitting']['scale'] > 0 and 0 < profile['pitting']['amount'] <= 1):
        raise ValueError('Pitting requires positive scale and bounded amount')
    if 'folds' in profile and not (profile['folds']['amplitude'] > 0 and profile['folds']['frequency'] > 0 and 0 <= profile['folds']['crease_start'] < 1):
        raise ValueError('Skin folds require positive amplitude/frequency and a bounded crease')
    if 'rim' in profile and min(profile['rim']['height'], profile['rim']['width']) <= 0:
        raise ValueError('Shell rim requires positive height and width')
