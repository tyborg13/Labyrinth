"""Channel-only measured clamps; protected director tracks remain untouched."""
from rr42_underlay import CASE
from cutout_pipeline.cases import read_json

FLOORS={('death','pelvis.lift_px'):3,('death','torso.lean_deg'):12,
        ('press','hand_near.lift_px'):10,('press','hand_near.forward_px'):12}

CLAMPS=CASE.parent/'rr42_feedback1_clamps.json'


def apply(data):
    rows=read_json(CLAMPS)['channels']
    for row in rows:
        clip,source,peak=row['clip'],row['source'],row['peak']
        if source.startswith('chain.') and (clip=='death' or source!='chain.angle_deg'):raise ValueError('Chain release, drop and angle remain director-authored')
        if peak<FLOORS.get((clip,source),0):raise ValueError('Clamp falls below director floor')
        for view in data['view_tracks']:
            if row.get('view') not in (None,view):continue
            track=next(t for t in data['view_tracks'][view][clip] if t['source']==source)
            target=max(abs(k['value']) for k in track['keys'])
            if not 0<=peak<=target:raise ValueError('Clamp must move only toward rest')
            if clip=='death' and source=='pelvis.lift_px' and peak<3:raise ValueError('Director hip floor is 3 px')
            if clip=='death' and source=='torso.lean_deg' and peak<12:raise ValueError('Director lean floor is 12 degrees')
            for key in track['keys']:key['value']*=peak/target
    return data
