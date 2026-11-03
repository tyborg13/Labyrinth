"""Director feedback 1: five named targets intentionally use runtime IK clamps.

This is case-owned approval, not a shared tolerance. Nonfinite targets and all
unlisted profiles still fail the ordinary reach gate. Keyed targets are kept.
"""
import numpy as np
from humanoid_cutout.reach import report as reach
from humanoid_cutout.action_direction import pose_values
from humanoid_cutout.bone_contracts import fk_world

ACCEPTED = frozenset({('front','broken_rhythm','hand_far'), ('front','death','hand_near'),
                      ('rear','peal','hand_near'), ('rear','broken_rhythm','hand_near'),
                      ('rear','death','hand_near')})
DENSE_INTERVALS = 1000


def report(layout, data, **geometry):
    result=reach(layout,data,**geometry);accepted=[];remaining=[]
    for error in result['errors']:
        tag=tuple(error.split(':',1)[0].split('/'))
        if tag in ACCEPTED and ': minimum reach ' in error:accepted.append(error)
        else:remaining.append(error)
    result.update(errors=remaining,ok=not remaining,director_accepted_runtime_clamps=accepted)
    return result


def excursions(layout,data):
    view=layout['facing'];j=layout['joints'];forward=np.asarray(data['projection'][view]['forward']);rows=[]
    for v,clip,hand in sorted(ACCEPTED):
        if v!=view:continue
        side=hand.removeprefix('hand_');first='upper_'+side;second='fore_'+side
        a,b,c=[np.asarray(j[n]['position'],float) for n in (first,second,hand)]
        lengths=[float(np.linalg.norm(b-a)),float(np.linalg.norm(c-b))]
        phases=sorted(set(np.linspace(0,1,DENSE_INTERVALS+1))|{k['at'] for t in data['view_tracks'][view][clip] for k in t['keys']})
        samples=[]
        for phase in phases:
            values,modes=pose_values(data,view,clip,phase);fk=fk_world(layout,values,modes,forward,0.,clip=clip)
            target=fk[first][:2,:2].T@(fk[hand][:2,2]-fk[first][:2,2]);distance=float(np.linalg.norm(target))
            actual=target*(float(np.clip(distance,abs(lengths[0]-lengths[1])+1e-6,sum(lengths)))/distance) if distance>1e-6 else c-a
            samples.append({'phase':float(phase),'target_excursion_px':float(np.linalg.norm(target-(c-a))),
                            'achieved_excursion_px':float(np.linalg.norm(actual-(c-a))),
                            'clamp_distance_px':float(np.linalg.norm(actual-target))})
        peak=max(samples,key=lambda r:r['target_excursion_px'])
        rows.append({'view':view,'clip':clip,'hand':hand,**peak,
                     'achieved_ratio':peak['achieved_excursion_px']/peak['target_excursion_px'],
                     'maximum_clamp_distance_px':max(r['clamp_distance_px'] for r in samples),
                     'clamped_samples':sum(r['clamp_distance_px']>1e-6 for r in samples),'samples':len(samples),
                     'budget_note':'Director feedback 1: exact keyed targets retained; this named profile may fall below 60% and use the existing physical IK clamp.'})
    return rows
