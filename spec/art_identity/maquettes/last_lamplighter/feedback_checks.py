"""Director feedback 1: native lames, folds, rolls, claws and visible lean."""
import math
import numpy as np
from .forms import TOPOLOGY
from .body import BODY_TOPOLOGY
from .garments import GARMENT_TOPOLOGY

MEASUREMENT_DEFAULTS={'shape_epsilon_m':1e-5,'pane_grid':65,'row_fraction':.75}


def feedback_values(spec,points,j,H,L):
    values={};lames={};details={};checks={}
    def put(name,value):values[name]=float(value)
    for side in ('near','far'):
        for finger in [*range(4),'thumb']:
            name=('finger_'+side+'_'+str(finger)) if finger!='thumb' else 'thumb_'+side
            rings=points[name].reshape(-1,TOPOLOGY['sweep_samples'],3);centres=rings.mean(1)
            put(name+'_thickness_over_H',2*np.linalg.norm(rings-centres[:,None],axis=2).mean()/H)
            put(name+'_length_over_H',np.linalg.norm(np.diff(centres,axis=0),axis=1).sum()/H)
        for part,a,b in [('upper','shoulder','elbow'),('fore','elbow','hand'),('thigh','hip','knee'),('shin','knee','ankle')]:
            v=points[part+'_plate_'+side];count=len(v)//(BODY_TOPOLOGY['lame_stations']*TOPOLOGY['ring_samples'])
            groups=v.reshape(count,BODY_TOPOLOGY['lame_stations'],TOPOLOGY['ring_samples'],3)
            axis=j[b+'_'+side]-j[a+'_'+side];axis/=np.linalg.norm(axis)
            spans=[np.einsum('nj,j->n',g.reshape(-1,3),axis) for g in groups]
            overlap=[float(spans[k].max()-spans[k+1].min()) for k in range(count-1)]
            axes=groups.mean(2)[:,-1]-groups.mean(2)[:,0];axes/=np.linalg.norm(axes,axis=1)[:,None]
            errors=np.degrees(np.arccos(np.clip(np.einsum('nj,j->n',axes,axis),-1,1)))
            lames[part+'_'+side]={'count':count,'overlap_m':overlap,'maximum_axis_error_degrees':float(errors.max())}
    checks['rounded_overlapping_lames']=all(2<=v['count']<=3 and min(v['overlap_m'])>MEASUREMENT_DEFAULTS['shape_epsilon_m'] and v['maximum_axis_error_degrees']<=1 for v in lames.values())
    barrel=points['iron_barrel'].reshape(-1,48,3).mean(1);axis=barrel[-1]-barrel[0]
    lean=math.degrees(math.atan2(axis[0],axis[2]));put('barrel_forward_lean',lean)
    roll=points['cowl_rolled_edge'].reshape(-1,TOPOLOGY['sweep_samples'],3);centres=roll.mean(1)
    put('cowl_roll_diameter_over_H',2*np.linalg.norm(roll-centres[:,None],axis=2).mean()/H)
    frame=points['rounded_lamp_frame'][:24].reshape(2,12,3);centre=frame.mean(1)
    put('lamp_frame_diameter_over_H',2*np.linalg.norm(frame-centre[:,None],axis=2).mean()/H)
    mullions=points['lamp_cross_mullions'].reshape(-1,12,3);mc=mullions.mean(1)
    put('lamp_mullion_diameter_over_H',2*np.linalg.norm(mullions-mc[:,None],axis=2).mean()/H)
    robe=points['tattered_robe'];n=len(robe)//2;mid=(robe[:n]+robe[n:])/2
    grid=mid.reshape(GARMENT_TOPOLOGY['rows'],GARMENT_TOPOLOGY['columns'],3)
    hem=grid[-1];knee=min(j['knee_near'][2],j['knee_far'][2]);midshin=(knee+min(j['ankle_near'][2],j['ankle_far'][2]))/2
    put('robe_hem_above_knee_over_L',max(0,hem[:,2].max()-knee)/L)
    put('robe_hem_below_midshin_over_L',max(0,midshin-hem[:,2].min())/L)
    # Fit the broad elliptical drape from opened samples, then measure actual
    # vertical fold residuals. No authored recipe vertex is an observation.
    row=grid[int((len(grid)-1)*MEASUREMENT_DEFAULTS['row_fraction'])]
    angles=np.linspace(math.pi/2,math.tau,len(row))
    baseline=np.column_stack([np.ones(len(row)),np.sin(angles),np.cos(angles),abs(np.sin(angles)),row[:,2]])
    fitted=np.einsum('ij,jk->ik',baseline,np.linalg.lstsq(baseline,row[:,:2],rcond=None)[0])
    residual=row[:,:2]-fitted
    folds=residual[:,0]*np.cos(angles)+residual[:,1]*np.sin(angles)
    crest=[k for k in range(1,len(folds)-1) if folds[k]>folds[k-1] and folds[k]>folds[k+1] and folds[k]>MEASUREMENT_DEFAULTS['shape_epsilon_m']]
    checks['soft_vertical_folds']=len(crest)>=spec['dimensions']['robe_folds_min']
    checks['hem_between_knee_and_midshin']=hem[:,2].min()>=midshin-.01*L and hem[:,2].max()<=knee+.01*L
    box=(points['lamp_roof'].mean(0)+points['lamp_floor'].mean(0))/2
    up=points['lamp_roof'].mean(0)-points['lamp_floor'].mean(0);up/=np.linalg.norm(up)
    lateral=np.cross(up,[1,0,0]);lateral/=np.linalg.norm(lateral)
    axes=[np.array([1,0,0]),lateral,up];frame=points['rounded_lamp_frame'];pane_recess=[]
    for pane in points['lamp_panes'].reshape(-1,8,3):
        centre=pane.mean(0)-box
        normal_axis=max(axes[:2],key=lambda a:abs(np.dot(centre,a)))
        frame_bound=np.max(abs(np.einsum('nj,j->n',frame-box,normal_axis)))
        pane_bound=np.max(abs(np.einsum('nj,j->n',pane-box,normal_axis)))
        pane_recess.append(float((frame_bound-pane_bound)/H))
    checks['panes_recessed_behind_bars']=min(pane_recess)>0
    head_up=j['head_tip']-j['head'];head_up/=np.linalg.norm(head_up)
    head_forward=np.cross([0,1,0],head_up);head_forward/=np.linalg.norm(head_forward)
    mask_front=np.max(np.einsum('nj,j->n',points['convex_mask']-j['head'],head_forward))
    roll_front=np.max(np.einsum('nj,j->n',points['cowl_rolled_edge']-j['head'],head_forward))
    checks['mask_deep_inside_roll']=roll_front>mask_front
    hood=points['draped_hood'];hood=(hood[:len(hood)//2]+hood[len(hood)//2:])/2
    back=hood.reshape(GARMENT_TOPOLOGY['rows'],GARMENT_TOPOLOGY['columns'],3)[:,GARMENT_TOPOLOGY['columns']//2]
    radii=-np.einsum('nj,j->n',back-j['head'],head_forward)
    checks['rounded_rear_cowl']=radii[-2]<radii[len(radii)//2] and not any(abs(radii[k]-radii[k-1])<MEASUREMENT_DEFAULTS['shape_epsilon_m'] and abs(radii[k+1]-radii[k])<MEASUREMENT_DEFAULTS['shape_epsilon_m'] for k in range(1,len(radii)-1))
    details['panes_minimum_recess_over_H']=min(pane_recess)
    details['mask_roll_recess_over_H']=float((roll_front-mask_front)/H)
    details['cowl_back_profile_radius_over_H']=(radii/H).tolist()
    details.update(lames=lames,fold_crests=len(crest),fold_depth_peak_to_peak_over_H=float(np.ptp(folds)/H),
        hem_z_range_m=[float(hem[:,2].min()),float(hem[:,2].max())],knee_z_m=float(knee),midshin_z_m=float(midshin),barrel_lean_degrees=lean)
    return values,checks,details


def valid_feedback(spec,native):
    """Counts and visibility observations cannot be replaced by summary flags."""
    report=native.get('feedback1',{});H=native.get('height_m',0);L=native.get('leg_length_m',0)
    expected={p+'_'+s for s in ('near','far') for p in ('upper','fore','thigh','shin')}
    lames=report.get('lames',{})
    if set(lames)!=expected or type(H) not in (int,float) or not math.isfinite(H) or H<=0 or type(L) not in (int,float) or not math.isfinite(L) or L<=0:return False
    if abs(H-spec['mq18']['height_m'])>.01*spec['mq18']['height_m'] or abs(L-spec['mq18']['leg_length_m'])>.01*spec['mq18']['leg_length_m']:return False
    for name,row in lames.items():
        count=row.get('count');overlap=row.get('overlap_m',[]);error=row.get('maximum_axis_error_degrees')
        if type(count) is not int or not 2<=count<=3 or len(overlap)!=count-1:return False
        if any(type(x) not in (int,float) or not math.isfinite(x) or x<=0 for x in overlap):return False
        if type(error) not in (int,float) or not math.isfinite(error) or error>1:return False
    folds=report.get('fold_crests');lean=report.get('barrel_lean_degrees')
    if type(folds) is not int or folds<spec['dimensions']['robe_folds_min']:return False
    if type(lean) not in (int,float) or not math.isfinite(lean) or abs(lean-spec['pose']['hip_lean_degrees'])>1:return False
    visibility=native.get('lantern_visibility',{})
    if visibility.get('passed') is not True or set(visibility.get('views',{}))!={'front','rear'}:return False
    for view,row in visibility['views'].items():
        if set(row.get('panes',{}))!={'lantern_pane_'+str(k) for k in range(6)}:return False
        equivalents=0
        for pane in row['panes'].values():
            n,total=pane.get('visible_samples'),pane.get('total_samples')
            if type(n) is not int or type(total) is not int or total!=MEASUREMENT_DEFAULTS['pane_grid']**2 or not 0<=n<=total:return False
            if pane.get('visible_pane_equivalent')!=n/total:return False
            equivalents+=n/total
        if row.get('visible_pane_equivalents')!=equivalents or equivalents<spec['dimensions']['lantern_clear_pane_equivalents_min']:return False
    candle=native.get('candle_visibility',{})
    return candle.get('passed') is True and all(candle.get('visibility',{}).get(v,{}).get('visible_surface_samples',0)>0 for v in ('front','rear'))
