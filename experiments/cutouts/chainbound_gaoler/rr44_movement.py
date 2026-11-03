"""Independent director pendulum and delayed held-channel acceptance."""
import math
import numpy as np
from humanoid_cutout.gait import schedule
from humanoid_cutout.gates import matrix, angle
from rr44_case import DEFAULTS


def wave(gait, side, phase):
    if phase <= 0 or phase >= 1: return 0.
    keys = [(0.,0.)]; swings = schedule(gait)
    for index,swing in enumerate(swings):
        amplitude = .5 if index in (0,len(swings)-1) else 1.
        keys.append((swing['end'],0. if index==len(swings)-1 else amplitude*(-1 if side==swing['side'] else 1)))
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if a<=phase<=b:
            u=(phase-a)/(b-a); return x+(y-x)*u*u*(3-2*u)
    raise ValueError('Outside gait schedule')


def expected(layout, definition, side, row, forward):
    phase=row['phase']; gait=definition['gait']; arm=gait['arm_swing'][side]
    ramp=gait['arm_swing']['envelope']['ramp_fraction']
    smooth=lambda x:(lambda u:u*u*(3-2*u))(min(1.,max(0.,x/ramp)))
    envelope=smooth(phase)*smooth(1-phase)
    w=wave(gait,side,phase)*envelope
    lag=wave(gait,side,phase-arm['forearm_lag_s']*envelope/definition['seconds'])*envelope
    a,b,c=[np.asarray(layout['joints'][n+'_'+side]['position']) for n in ('upper','fore','hand')]
    torso=matrix(row.get('direction_bones',row['bones'])['torso']['global']); base=math.atan2(torso[1,0],torso[0,0])
    direction=np.sign((c-a)[0]*forward[1]-(c-a)[1]*forward[0]); flex_sign=-np.sign(forward[0])
    upper=base+math.radians(arm['upper_deg']*w*direction)
    fore=base+math.radians(arm['upper_deg']*lag*direction+abs(lag)*arm['forearm_bend_deg']['forward' if lag>=0 else 'back']*flex_sign)
    flex=((math.atan2(*(c-b)[::-1])+fore-math.atan2(*(b-a)[::-1])-upper+math.pi)%(2*math.pi)-math.pi)*flex_sign
    if flex<0: fore-=flex*flex_sign
    return upper,fore


def report(layout, data, director, samples):
    view=layout['facing']; definition=director['chainbound_gaoler']['clips']['move']
    forward=np.asarray(data['projection'][view]['forward']); errors=[]; rows=[]
    for row in samples['samples']:
        if row['view']!=view or row['clip']!='move': continue
        for side in ('near','far'):
            upper,fore=expected(layout,definition,side,row,forward)
            for bone,want in [('upper_'+side,upper),('fore_'+side,fore),('hand_'+side,fore)]:
                actual=math.radians(angle(row['bones'][bone]['global']))
                tolerance=DEFAULTS['matrix_tolerance'] if row['kind']=='authored' else math.radians(DEFAULTS['presentation_angle_tolerance_deg'])
                error=abs((actual-want+math.pi)%(2*math.pi)-math.pi)
                rows.append(dict(frame=row['frame'],phase=row['phase'],kind=row['kind'],bone=bone,error_rad=error))
                if error>tolerance: errors.append(f'{view}/move/{row["frame"]}/{row["kind"]}/{bone}: pendulum differs from director')
    if not rows: errors.append(view+': missing pendulum evidence')
    return dict(ok=not errors,errors=errors,frames=rows)


def held_report(layout, data, director, samples, *, allow_placeholder=False):
    view=layout['facing']; follow=director['chainbound_gaoler']['clips']['move']['held_follow']
    mode=data['clips']['move']['held_follow']['reference_frame']; errors=[]; rows=[]
    if mode.startswith('TODO_DESIGN_'):
        return dict(ok=allow_placeholder,errors=[] if allow_placeholder else [mode],frames=[],pending_design=True)
    sign=data['projection'][view]['lean_sign']*layout['held_items'][follow['item']].get('angle_sign',1)
    for row in samples['samples']:
        if row['view']!=view or row['clip']!='move': continue
        reference=row.get('held_follow_reference')
        if reference is None: errors.append(view+': missing delayed grip reference'); continue
        if reference['phase']<0:displacement=0.
        elif mode=='body':
            hand=follow['grip'];point=np.asarray(layout['held_items'][follow['item']].get('source_grip',layout['joints'][hand]['position']))
            grip=matrix(reference['body_hand'])@np.append(point-layout['joints'][hand]['position'],1)
            local=np.linalg.inv(matrix(reference['body_torso']))@grip
            displacement=(local[:2]-(point-layout['joints']['torso']['position']))@np.asarray(data['projection'][view]['forward'])
        else:displacement=reference['displacement_'+mode]
        want=displacement*follow['deg_per_px']*sign
        actual=angle(row['bones'][follow['item']]['global'])
        tolerance=DEFAULTS['matrix_tolerance'] if row['kind']=='authored' else DEFAULTS['presentation_angle_tolerance_deg']
        error=abs((actual-want+180)%360-180)
        rows.append(dict(frame=row['frame'],kind=row['kind'],expected_deg=want,actual_deg=actual))
        if error>tolerance: errors.append(f'{view}/move/{row["frame"]}: held_follow differs from director grip/lag/gain')
    if not rows: errors.append(view+': missing held_follow evidence')
    return dict(ok=not errors,errors=errors,frames=rows,pending_design=False)
