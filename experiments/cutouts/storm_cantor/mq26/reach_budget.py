"""Measure case hand excursions on a dense grid; preserve the director source."""
import numpy as np
from humanoid_cutout.gait import evaluate
SEARCH_DENOMINATOR=60
DENSE_INTERVALS=1000
MIN_APPROVED_EXCURSION=0.6
POSITION_CHANNELS=('forward_px','lift_px','inward_px')

def apply(data,layouts):
    from reach_acceptance import ACCEPTED,excursions
    profiles=[];clamps=[];placeholders={}
    for view,clips in data['view_tracks'].items():
        j=layouts[view]['joints'];forward=np.asarray(data['projection'][view]['forward'])
        for clip,tracks in clips.items():
            if clip=='move':continue # Both approved shoulder pendulums retain ratio 1.0.
            for side in ('near','far'):
                hand='hand_'+side;selected=[t for t in tracks if t['bone']==hand and t['channel'] in POSITION_CHANNELS]
                if not selected:continue
                a,b,c=[np.asarray(j[n+'_'+side]['position'],float) for n in ('upper','fore','hand')]
                lengths=[float(np.linalg.norm(b-a)),float(np.linalg.norm(c-b))]
                phases=sorted(set(np.linspace(0,1,DENSE_INTERVALS+1))|{k['at'] for t in selected for k in t['keys']})
                delta=np.zeros((len(phases),2))
                for t in selected:
                    v=np.asarray([evaluate(t['keys'],p) for p in phases])
                    if t['channel']=='forward_px':delta+=v[:,None]*forward
                    elif t['channel']=='lift_px':delta[:,1]-=v
                    else:delta[:,0]+=v*np.sign(j['root']['position'][0]-c[0])
                low=abs(lengths[0]-lengths[1])+4;high=sum(lengths)*1.02
                trials=[];factor=None
                for n in range(SEARCH_DENOMINATOR,round(MIN_APPROVED_EXCURSION*SEARCH_DENOMINATOR)-1,-1):
                    f=n/SEARCH_DENOMINATOR;dist=np.linalg.norm(c-a+delta*f,axis=1);ok=bool(dist.min()>=low and dist.max()<=high)
                    trials.append({'ratio':f,'minimum_px':float(dist.min()),'maximum_px':float(dist.max()),'ok':ok})
                    if ok:factor=f;break
                status='full_requested' if factor==1 else 'measured_and_clamped' if factor is not None else 'TODO_DESIGN_reach'
                row={'view':view,'clip':clip,'hand':hand,'ratio':factor if factor is not None else 1.0,'status':status,'allowed_minimum_px':low,'allowed_maximum_px':high,'trials':trials}
                if (view,clip,hand) in ACCEPTED:
                    row.update(ratio=1.0,status='director_accepted_runtime_clamp',budget_note='Feedback 1: preserve the exact keyed targets; runtime IK clamps this named profile, below the 60% floor if needed.')
                elif factor is None:
                    name=f'TODO_DESIGN_{view}_{clip}_{hand}_reach';placeholders[name]='No reachable profile at 60–100% of the approved target on the independently registered painted limb. Original target retained; runtime IK clamps, director resolution required.';row['placeholder']=name
                elif factor!=1:
                    for t in selected:
                        for key in t['keys']:
                            old=key['value'];key['value']*=factor
                            if old!=key['value']:clamps.append({'view':view,'clip':clip,'source':t['source'],'at':key['at'],'target':old,'clamped':key['value'],
                                'budget_note':'Largest dense measured reach-safe excursion on the Reaver 1/60 grid, at least 60% of director targets. Source bytes unchanged.'})
                profiles.append(row)
    achieved=[row for layout in layouts.values() for row in excursions(layout,data)]
    data.setdefault('budget_clamps',[]).extend(clamps+achieved)
    return {'profiles':profiles,'clamps':clamps,'runtime_clamps':achieved,'placeholders':placeholders,'walk_arm_excursion_ratios':{'near':1.0,'far':1.0},'dense_intervals':DENSE_INTERVALS,'search_denominator':SEARCH_DENOMINATOR,'native_pixels':False}
