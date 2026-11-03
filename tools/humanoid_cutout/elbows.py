"""Facing-owned elbow policy and an independent signed-flexion gate."""
import math
import numpy as np


def validate_policy(policy, layouts):
    if (policy.get('bend') != 'flex_toward_facing' or
            not set(policy.get('views', [])) <= set(layouts) or
            not policy.get('views') or not policy.get('sides') or
            not set(policy['sides']) <= {'near', 'far'} or
            type(policy.get('max_hyperextension_deg')) not in (int, float) or
            not math.isfinite(policy['max_hyperextension_deg']) or policy['max_hyperextension_deg'] < 0):
        raise ValueError('TODO_DESIGN_elbow_policy')


def flexion(points, forward):
    a, b, c = np.asarray(points, float)
    u, v = b-a, c-b
    return math.degrees(math.atan2(float(u[0]*v[1]-u[1]*v[0]), float(u@v))) * -float(np.sign(forward[0]))


def report(layout, data, samples, *, require_policy=True, threshold=None):
    policy = data.get('elbow_policy')
    errors, frames = [], []
    if require_policy and not policy:
        errors.append('elbow_policy missing')
    limit = threshold if threshold is not None else (policy or {}).get('max_hyperextension_deg', 2)
    view = layout['facing']
    forward = data['projection'][view]['forward']
    for row in samples['samples']:
        if row['view'] != view: continue
        for family, bones in [('canonical', row['bones'])] + ([('native_origin', row['raster_bones'])] if 'raster_bones' in row else []):
            for side in ('near', 'far'):
                names = [n+'_'+side for n in ('upper', 'fore', 'hand')]
                if not all(n in bones for n in names): continue
                points = [bones[n]['global'][4:] for n in names]
                signed = flexion(points, forward)
                record = dict(view=view, clip=row['clip'], frame=row['frame'], kind=row['kind'],
                              phase=row['phase'], family=family, side=side, signed_flexion_deg=signed,
                              points=points, passed=signed >= -limit)
                frames.append(record)
                if not record['passed']:
                    errors.append(f'{view}/{row["clip"]}/{row["frame"]}/{row["kind"]}/{family}/{side}: elbow {signed:.6f} < {-limit}')
    if not frames: errors.append(view+': missing elbow evidence')
    return dict(ok=not errors, errors=errors, frames=frames, max_hyperextension_deg=limit)
