"""Feedback dimensions measured from opened world-space meshes, never inputs."""
import math
import numpy as np

VOLUME_LIMITS={'ratio_error':.001,'thickness_epsilon_m':1e-6,'shape_epsilon_m':1e-5}
# Proof tolerances, not construction inputs. A cap must have a substantial rise
# above its rim, separated inner/outer skins and a rim over its shoulder. Plate
# bounds must reach both joints; checking diameter alone accepts tiny cuffs.
SHAPE_LIMITS={'minimum_dome_rise_over_radius':.25,'minimum_shell_separation_over_H':.001,
              'maximum_rim_offset_over_H':.02,'minimum_armour_joint_span':.9,
              'maximum_armour_endpoint_error':.05}
LIMB_JOINTS={'upper':('shoulder','elbow'),'fore':('elbow','hand'),
             'thigh':('hip','knee'),'shin':('knee','ankle')}


def shape_checks(measurements):
    """Recompute every shape result from reported numerical observations."""
    checks={}
    for side in ('near','far'):
        dome=measurements['domes'][side]
        checks['pauldron_'+side+'_has_rise']=dome['rise_over_radius']>=SHAPE_LIMITS['minimum_dome_rise_over_radius']
        checks['pauldron_'+side+'_separated_shell']=dome['minimum_shell_separation_over_H']>=SHAPE_LIMITS['minimum_shell_separation_over_H']
        checks['pauldron_'+side+'_over_joint']=abs(dome['rim_above_shoulder_over_H'])<=SHAPE_LIMITS['maximum_rim_offset_over_H']
        for part in LIMB_JOINTS:
            item=measurements['armour'][part+'_plate_'+side]
            checks[part+'_plate_'+side+'_covers_joints']=(
                item['end_over_bone']-item['start_over_bone']>=SHAPE_LIMITS['minimum_armour_joint_span'] and
                abs(item['start_over_bone'])<=SHAPE_LIMITS['maximum_armour_endpoint_error'] and
                abs(item['end_over_bone']-1)<=SHAPE_LIMITS['maximum_armour_endpoint_error'])
    return checks


def required_checks(spec):
    """Derive the complete inventory from the actual compiled rib/spike IDs."""
    required={'three_vertical_tabard_folds','three_cloak_tails','cloak_narrows_downward','five_separate_curved_ribs',
              'domes_with_one_lame','domed_caps_not_spheres','sash_knot_present','feedback_dimensions'}
    for name in spec['volume_layout']['barrel_rib_ids']:
        required.update({name+'_wraps_sternum_to_spine',name+'_curved_in_three_dimensions'})
    required.update(name+'_swept_back' for name in spec['volume_layout']['spike_rings'])
    for side in ('near','far'):
        required.update('pauldron_'+side+suffix for suffix in ('_has_rise','_separated_shell','_over_joint'))
        required.update(part+'_plate_'+side+'_covers_joints' for part in LIMB_JOINTS)
    return required


def valid_shape_inventory(shapes):
    if (not isinstance(shapes,dict) or set(shapes)!={'domes','armour'} or
        set(shapes['domes'])!={'near','far'} or
        set(shapes['armour'])!={p+'_plate_'+s for p in LIMB_JOINTS for s in ('near','far')}):return False
    for kind,items in shapes.items():
        fields=({'rise_over_H','rise_over_radius','minimum_shell_separation_over_H','rim_above_shoulder_over_H'}
                if kind=='domes' else {'start_over_bone','end_over_bone'})
        for item in items.values():
            if not isinstance(item,dict) or set(item)!=fields or any(not isinstance(v,(int,float)) or isinstance(v,bool) or not math.isfinite(v) for v in item.values()):return False
    return True


def observe_volumes(spec,points,joints,H):
    p={k.removesuffix('_render'):np.asarray(v,float) for k,v in points.items()}
    d=spec['feedback1'];layout=spec['volume_layout'];rows=[];checks={};shapes={'armour':{},'domes':{}}
    def row(name,target,measured,minimum=False):
        error=measured-target
        passed=(error>=-VOLUME_LIMITS['thickness_epsilon_m']/H) if minimum else abs(error)<=VOLUME_LIMITS['ratio_error']
        rows.append({'name':name,'target_over_H':target,'measured_over_H':float(measured),'minimum':minimum,'passed':bool(passed)})
    from .sweep_volume import diameter
    for side in ('near','far'):
        for name in ('upper','fore','thigh','shin'):
            key=name+'_plate_'+side;axes=np.asarray(layout['limb_axes'][key])
            extent=[np.ptp(np.einsum('nj,j->n',p[key],axis)) for axis in axes]
            for index,value in enumerate(extent):row(key+'_diameter_axis'+str(index),d[name+'_diameter'],value/H)
            a,b=LIMB_JOINTS[name];start=np.asarray(joints[a+'_'+side]);delta=np.subtract(joints[b+'_'+side],start)
            along=(p[key]-start)@delta/np.dot(delta,delta)
            shapes['armour'][key]={'start_over_bone':float(along.min()),'end_over_bone':float(along.max())}
        for joint in ('elbow','knee'):row(joint+'_'+side+'_diameter',d['joint_diameter'],np.ptp(p[joint+'_joint_'+side][:,1])/H)
        row('gauntlet_'+side+'_width',d['gauntlet_width'],np.ptp(p['gauntlet_'+side][:,1])/H)
        for finger in ['finger_'+side+'_'+str(k) for k in range(4)]+['thumb_'+side]:
            row(finger+'_diameter',d['finger_diameter'],diameter(p[finger])/H)
        row('sabatons_'+side+'_past_toes',d['sabatons_past_toes'],(p['pointed_sabaton_'+side][:,0].max()-joints['foot_tip_'+side][0])/H)
    barrel=np.concatenate([p['closed_back_plate']]+[p[name] for name in layout['barrel_rib_ids']])
    row('barrel_width',d['barrel_width'],np.ptp(barrel[:,1])/H)
    armour=np.concatenate([values for key,values in p.items() if key.startswith(('pauldron_','shoulder_spike_'))])
    row('pauldron_outer_span',d['pauldron_outer_span'],np.ptp(armour[:,1])/H)
    for side,sign in (('near',1),('far',-1)):
        row('pauldron_'+side+'_across',d['pauldron_dome_across'],np.ptp(p['pauldron_'+side][:,layout['pauldron_across_axis']])/H)
        row('pauldron_'+side+'_outward_offset',d['pauldron_outward_offset'],sign*(p['pauldron_'+side][:,1].mean()-joints['shoulder_'+side][1])/H)
    row('bell_mouth_width',d['bell_mouth'],np.ptp(p['bell'][:,1])/H)
    for name in layout['barrel_rib_ids']:row(name+'_diameter',d['rib_diameter'],diameter(p[name])/H)
    for name,(a,b) in spec['mq17']['staff_components'].items():
        if name=='pennant':continue
        target=d['staff_shaft_diameter'] if name=='shaft' else d['fork_tine_diameter']
        suffix='_diameter' if name=='shaft' else '_base_diameter'
        section=p['staff'][a:b] if name=='shaft' else p['staff'][a:a+12]
        row('staff_'+name+suffix,target,diameter(section)/H)
    for name,count in layout['cloth_pairs'].items():
        distances=np.linalg.norm(p[name][:count]-p[name][count:],axis=1)
        row(name+'_minimum_thickness',d['cloth_min_thickness'],distances.min()/H,True)
    a,count=layout['pennant_pairs'];cloth=p['staff'][a:a+count*2]
    row('pennant_minimum_thickness',d['cloth_min_thickness'],np.linalg.norm(cloth[:count]-cloth[count:],axis=1).min()/H,True)
    nr,nc=layout['neck_roll_shape'];roll=p['neck_roll'].reshape(nr,nc,3)
    row('scarf_roll_thickness',d['scarf_roll_thickness'],np.ptp(roll[:,:,2])/H)
    sash=p['waist_sash'].reshape(24,48,3)
    row('sash_minimum_thickness',d['cloth_min_thickness'],np.linalg.norm(sash[0]-sash[12],axis=1).min()/H,True)
    knot=p['sash_knot'].reshape(2,33,12,3)
    row('knot_minimum_thickness',d['cloth_min_thickness'],np.linalg.norm(knot[:,:,:6]-knot[:,:,6:],axis=3).min()/H,True)
    tab=p['front_tabard'];nr,nc=layout['tabard_grid'];mid=(tab[:nr*nc]+tab[nr*nc:])/2;grid=mid.reshape(nr,nc,3)
    row('tabard_width',d['tabard_width'],np.ptp(tab[:,1])/H)
    # Three actual forward crests at a clear free-hanging section, away from
    # pelvic support. No source fold count or amplitude substitutes for vertices.
    section=grid[nr//2,:,0];crests=sum(section[k]>max(section[k-1],section[k+1])+VOLUME_LIMITS['shape_epsilon_m'] for k in range(1,nc-1))
    checks['three_vertical_tabard_folds']=crests>=d['tabard_vertical_folds']
    cloak=p['near_cloak_streamer'];nr,nc=layout['cloak_grid'];mid=(cloak[:nr*nc]+cloak[nr*nc:])/2;grid=mid.reshape(nr,nc,3)
    row('cloak_top_width',d['cloak_top_width'],np.ptp(grid[0,:,1])/H)
    hem=grid[-1,:,2];tails=sum(hem[k]<min(hem[k-1],hem[k+1])-VOLUME_LIMITS['shape_epsilon_m'] for k in range(1,nc-1))
    checks['three_cloak_tails']=tails==d['cloak_tails']
    checks['cloak_narrows_downward']=bool(np.ptp(grid[-1,:,1])<np.ptp(grid[0,:,1]))
    checks['five_separate_curved_ribs']=len(layout['barrel_rib_ids'])==d['rib_count'] and all(name in p for name in layout['barrel_rib_ids'])
    for name in layout['barrel_rib_ids']:
        centers=p[name].reshape(-1,12,3).mean(axis=1)
        checks[name+'_wraps_sternum_to_spine']=bool(centers[:,0].min()<0<centers[:,0].max() and np.ptp(centers[:,1])>.1*H)
        checks[name+'_curved_in_three_dimensions']=bool(np.ptp(centers[:,2])>VOLUME_LIMITS['shape_epsilon_m'])
    for name,count in layout['spike_rings'].items():
        centers=p[name].reshape(-1,count,3).mean(axis=1)
        row(name+'_length',d['pauldron_spike_length'],np.linalg.norm(np.diff(centers,axis=0),axis=1).sum()/H)
        checks[name+'_swept_back']=bool(centers[-1,0]<centers[0,0])
    checks['domes_with_one_lame']=all('pauldron_'+s in p and 'pauldron_lame_'+s in p for s in ('near','far'))
    checks['domed_caps_not_spheres']=all(p['pauldron_'+s][:,2].min()>=joints['shoulder_'+s][2]-VOLUME_LIMITS['shape_epsilon_m'] for s in ('near','far'))
    from .forms import DOME_TOPOLOGY
    for side in ('near','far'):
        cap=p['pauldron_'+side];outer,inner=np.split(cap,2);rim=outer[-DOME_TOPOLOGY['columns']:]
        rise=outer[0,2]-rim[:,2].mean();radius=np.ptp(rim[:,0])/2
        shapes['domes'][side]={'rise_over_H':float(rise/H),'rise_over_radius':float(rise/radius),
            'minimum_shell_separation_over_H':float(np.linalg.norm(outer-inner,axis=1).min()/H),
            'rim_above_shoulder_over_H':float((rim[:,2].mean()-joints['shoulder_'+side][2])/H)}
    checks.update(shape_checks(shapes))
    checks['sash_knot_present']='sash_knot' in p and 'medallion_hanger' in p
    checks['feedback_dimensions']=all(r['passed'] for r in rows)
    return {'passed':all(checks.values()),'checks':{k:bool(v) for k,v in checks.items()},'rows':rows,
            'shape_measurements':shapes,'tabard_crests':int(crests),'cloak_tails':int(tails),'definition':'Body-space H measured from opened helm tine to planted soles. Limb diameters are transverse to their approved bone axes; gauntlet width is its armour palm, excluding articulated fingers.'}


def valid_report(spec,report):
    expected={};d=spec['feedback1']
    for side in ('near','far'):
        for part in ('upper','fore','thigh','shin'):
            for axis in range(2):expected[part+'_plate_'+side+'_diameter_axis'+str(axis)]=(d[part+'_diameter'],False)
        for joint in ('elbow','knee'):expected[joint+'_'+side+'_diameter']=(d['joint_diameter'],False)
        expected['gauntlet_'+side+'_width']=(d['gauntlet_width'],False)
        for finger in ['finger_'+side+'_'+str(k) for k in range(4)]+['thumb_'+side]:expected[finger+'_diameter']=(d['finger_diameter'],False)
        expected['sabatons_'+side+'_past_toes']=(d['sabatons_past_toes'],False)
        expected['pauldron_'+side+'_across']=(d['pauldron_dome_across'],False)
        expected['pauldron_'+side+'_outward_offset']=(d['pauldron_outward_offset'],False)
    expected['bell_mouth_width']=(d['bell_mouth'],False)
    for name in spec['volume_layout']['barrel_rib_ids']:expected[name+'_diameter']=(d['rib_diameter'],False)
    for name in spec['mq17']['staff_components']:
        if name!='pennant':expected['staff_'+name+('_diameter' if name=='shaft' else '_base_diameter')]=(d['staff_shaft_diameter'] if name=='shaft' else d['fork_tine_diameter'],False)
    for name,key in [('barrel_width','barrel_width'),('pauldron_outer_span','pauldron_outer_span'),
                     ('scarf_roll_thickness','scarf_roll_thickness'),('tabard_width','tabard_width'),('cloak_top_width','cloak_top_width')]:
        expected[name]=(d[key],False)
    for name in spec['volume_layout']['cloth_pairs']:expected[name+'_minimum_thickness']=(d['cloth_min_thickness'],True)
    for name in ('pennant','sash','knot'):expected[name+'_minimum_thickness']=(d['cloth_min_thickness'],True)
    for name in spec['volume_layout']['spike_rings']:expected[name+'_length']=(d['pauldron_spike_length'],False)
    rows=report.get('rows',[])
    if len(rows)!=len(expected) or {r.get('name') for r in rows}!=set(expected):return False
    for r in rows:
        target,minimum=expected[r['name']];measured=r.get('measured_over_H')
        if not isinstance(measured,(int,float)) or isinstance(measured,bool) or not math.isfinite(measured) or r.get('target_over_H')!=target or r.get('minimum') is not minimum:return False
        if r.get('passed') is not True:return False
        if minimum:
            if measured<target-VOLUME_LIMITS['thickness_epsilon_m']/spec['volume_layout']['reference_height_m']:return False
        elif abs(measured-target)>VOLUME_LIMITS['ratio_error']:return False
    shapes=report.get('shape_measurements',{})
    if not valid_shape_inventory(shapes):return False
    observed=shape_checks(shapes)
    if not all(observed.values()) or any(report.get('checks',{}).get(k) is not v for k,v in observed.items()):return False
    return (report.get('passed') is True and required_checks(spec)==set(report.get('checks',{})) and
            all(value is True for value in report['checks'].values()) and report.get('tabard_crests',0)>=d['tabard_vertical_folds'] and report.get('cloak_tails')==d['cloak_tails'])
