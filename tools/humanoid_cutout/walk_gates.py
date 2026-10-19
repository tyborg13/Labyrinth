"""Both-leg walk gates, independent of the runtime's IK implementation."""
import math
import json
from functools import lru_cache
from pathlib import Path

import numpy as np

from .gait import schedule, SIDES
from .bone_contracts import fk_world, leg_bend_side
from .anatomy import for_layout
from .action_direction import pose_values

EPSILON = .0001  # Serialized Bone2D tolerance.
TARGET_TOLERANCE_PX = .7072  # Director's rounded sqrt(2)/2 presentation radius.
MINIMUM_SWING_PEAK_DEG = 15.
MAX_RIGID_AIR_PX = 3.
RIGID_AIR_CACHE_ENTRIES = 16


def knee(row, side):
    a, b, c = [np.asarray(row['bones'][n+'_'+side]['global'][4:]) for n in ('thigh', 'shin', 'foot')]
    upper, lower = b-a, c-b
    cross = upper[0]*lower[1]-upper[1]*lower[0]
    bend = abs(math.degrees(math.atan2(float(cross), float(upper@lower))))
    pole = (c-a)[0]*(b-a)[1]-(c-a)[1]*(b-a)[0]
    return {'bend_deg': bend, 'pole': float(pole)}


def rigid_air_errors(records):
    return [f'{r["joint"]}: rigid air {r["air_px"]:.6f} px > 3' for r in records if r['air_px'] > MAX_RIGID_AIR_PX + EPSILON]


def skinned(layout, side):
    """Match humanoid_gait.gd: classify a leg by its two mesh-weight keys."""
    return any('thigh_'+side in mesh.get('weights', {}) and
               'shin_'+side in mesh.get('weights', {})
               for mesh in layout.get('joint_meshes', []))


def rigid_sides(layout):
    return tuple(side for side in SIDES if not skinned(layout, side))


def report(layout, data, samples):
    view = layout['facing']
    gait = data['clips']['move']['gait']
    forward = np.asarray(data['projection'][view]['forward'])
    if not samples.get('samples') or samples.get('screen_pixel_scale', 0) <= 0 or 'step_distance_px' not in samples:
        return {'ok':False,'errors':[view+': missing walk evidence'],'frames':[],'stance':[],'swings':[],
                'minimum_peak_bend_deg':0.,'maximum_fit_px':0.,'maximum_total_pelvis_drop_px':0.,
                'maximum_rigid_air_px':0.,'maximum_stance_frame_change_px':0.,'maximum_stance_target_error_px':0.}
    step = samples['step_distance_px']/samples['screen_pixel_scale']
    errors, frames, stances, swings, air = [], [], [], [], []
    rows = sorted([r for r in samples['samples'] if r['view']==view and r['clip']=='move'],key=lambda r:(r['kind'],r['phase']))
    previous = {}
    anatomy = for_layout(layout)
    for row in rows:
        phase = row['phase']
        values, modes = pose_values(data,view,'move',phase)
        fk = fk_world(layout,values,modes,forward,step)
        # Undo the independently computed fit before measuring its exact need.
        authored_pelvis = np.asarray(layout['joints']['pelvis']['position']) + forward*phase*step
        authored_pelvis += forward*values.get('pelvis',{}).get('forward_px',0.) + [0.,-values['pelvis']['lift_px']]
        actual_pelvis = np.asarray(row['bones']['pelvis']['global'][4:])
        fit = float(fk['pelvis'][1,2]-authored_pelvis[1])
        total = float(fk['pelvis'][1,2]-layout['joints']['pelvis']['position'][1]-forward[1]*phase*step)
        record = {'frame':row['frame'],'phase':phase,'kind':row['kind'],'fit_px':fit,'pelvis_drop_px':total,'legs':{}}
        if fit > gait['max_fit_px']+EPSILON: errors.append(f'{view}/move/{phase}: pelvis fit {fit:.6f} px > {gait["max_fit_px"]}')
        limit = TARGET_TOLERANCE_PX if row['kind']=='presented' else EPSILON*4
        if np.linalg.norm(actual_pelvis-fk['pelvis'][:2,2]) > limit:
            errors.append(f'{view}/move/{phase}: pelvis fit differs from authored-offset fit')
        if total < -EPSILON: errors.append(f'{view}/move/{phase}: pelvis above rest')
        for side in SIDES:
            foot = 'foot_'+side
            a,b,c = [np.asarray(layout['joints'][n+'_'+side]['position']) for n in ('thigh','shin','foot')]
            v = values[foot]
            scale = float(np.clip(1 + forward[1]*(v['forward_px']-phase)*step/(np.linalg.norm(b-a)+np.linalg.norm(c-b)),.78,gait.get('leg_scale_max',1.22)))
            target = c + [v['lane_px'], -v['lift_px']] + forward*v['forward_px']*step
            actual = np.asarray(row['bones'][foot]['global'][4:])
            snapped = c + np.rint(actual-c) if row['kind']=='presented' else actual
            error = float(np.linalg.norm(snapped-target))
            if error > limit: errors.append(f'{view}/move/{side}/frame {row["frame"]}: foot target error {error:.6f} px')
            start = fk['thigh_'+side][:2,2]
            length = float(np.linalg.norm(b-a)+np.linalg.norm(c-b))
            if np.linalg.norm(target-start) > length*scale + EPSILON:
                errors.append(f'{view}/move/{side}/{phase}: leg overreach after scale and fit')
            k = knee(row,side)
            if k['bend_deg'] > anatomy['knee_policy']['near_straight_deg'] and k['pole']*leg_bend_side(layout,anatomy,side,view) < -EPSILON:
                errors.append(f'{view}/move/{side}/frame {row["frame"]}: bent knee against facing')
            active = next((s for s in schedule(gait) if s['side']==side and s['start'] < phase < s['end']),None)
            leg = {**k,'scale':scale,'target':target.tolist(),'planted':active is None,'target_error_px':error,'frame_change_px':0.}
            if active is None:
                # Stance membership comes from the protected schedule, never
                # from mutable lift keys (zero-lift swings must still fail).
                key=(row['kind'],side)
                old=previous.get(key)
                if old is not None and row['frame']==old['frame']+1 and row['kind']=='presented':
                    leg['frame_change_px']=float(np.linalg.norm(snapped-old['actual']))
                    if leg['frame_change_px'] != 0.: errors.append(f'{view}/move/{side}/frame {row["frame"]}: stance moved {leg["frame_change_px"]:.6f} px')
                previous[key]={'frame':row['frame'],'actual':snapped}
                stances.append({'side':side,**record,**leg})
            else:
                previous.pop((row['kind'],side),None)
                expected_lift=gait['lift_px']*math.sin(math.pi*(phase-active['start'])/(active['end']-active['start']))**1.35
                if abs(v['lift_px']-expected_lift)>EPSILON:
                    errors.append(f'{view}/move/{side}/{phase}: swing lift differs from protagonist curve')
            record['legs'][side]=leg
        frames.append(record)
    presented=[r for r in frames if r['kind']=='presented']
    for s in schedule(gait):
        side=s['side'];other='far' if side=='near' else 'near'
        candidates=[r for r in presented if s['start']<r['phase']<s['end']]
        if not candidates:
            errors.append(f'{view}/{side}: missing swing frames');continue
        peak=max(candidates,key=lambda r:r['legs'][side]['bend_deg'])
        apex=min(candidates,key=lambda r:abs(r['phase']-(s['start']+s['end'])/2))
        swing={**s,'peak_frame':peak['frame'],'peak_bend_deg':peak['legs'][side]['bend_deg'],
               'apex_frame':apex['frame'],'apex_swing_bend_deg':apex['legs'][side]['bend_deg'],
               'apex_stance_bend_deg':apex['legs'][other]['bend_deg']}
        swings.append(swing)
        if swing['peak_bend_deg']+EPSILON < MINIMUM_SWING_PEAK_DEG: errors.append(f'{view}/{side}: peak knee below 15 degrees')
        if swing['apex_swing_bend_deg']<=swing['apex_stance_bend_deg']+EPSILON: errors.append(f'{view}/{side}: apex swing knee does not exceed stance knee')
    if not rows: errors.append(view+': missing walk evidence')
    air = joint_air(layout, rows)
    errors += rigid_air_errors(air)
    return {'ok':not errors,'errors':sorted(set(errors)),'frames':frames,'stance':stances,'swings':swings,
            'minimum_peak_bend_deg':min((s['peak_bend_deg'] for s in swings),default=0.),
            'maximum_fit_px':max((r['fit_px'] for r in frames),default=0.),
            'maximum_total_pelvis_drop_px':max((r['pelvis_drop_px'] for r in frames),default=0.),
            'maximum_rigid_air_px':max((r['air_px'] for r in air),default=0.),'rigid_air':air,
            'maximum_stance_frame_change_px':max((r['frame_change_px'] for r in stances),default=0.),
            'maximum_stance_target_error_px':max((r['target_error_px'] for r in stances),default=0.)}


def joint_air(layout, rows):
    bones={name+'_'+side for side in rigid_sides(layout) for name in ('thigh','shin','foot')}
    if not bones: return []
    path=layout['motion_data']
    project=Path(__file__).resolve().parents[2]
    case=(project/path[6:] if path.startswith('res://') else Path(path)).parent
    fingerprints=tuple((p['file'],(case/p['file']).stat().st_mtime_ns,(case/p['file']).stat().st_size)
                       for p in layout['parts'] if p['bone'] in bones)
    presented=[{k:r[k] for k in ('kind','frame','parts')} for r in rows if r['kind']=='presented']
    return _joint_air(json.dumps(layout,sort_keys=True),json.dumps(presented,sort_keys=True),fingerprints)


@lru_cache(maxsize=RIGID_AIR_CACHE_ENTRIES)
def _joint_air(layout_json, rows_json, fingerprints):
    """Nearest painted pixel-square separation of each adjacent rigid joint.

    Use all visible and hidden source texels; a leg's overlap closes before
    any air opens. Convex support is not used (it would fill concave gaps).
    """
    layout, rows = json.loads(layout_json), json.loads(rows_json)
    from PIL import Image
    from .gates import matrix
    path = layout['motion_data']
    project = Path(__file__).resolve().parents[2]
    case = (project / path[6:] if path.startswith('res://') else Path(path)).parent
    from .rigid_joint_gap import gap
    sides=rigid_sides(layout)
    bones={name+'_'+side for side in sides for name in ('thigh','shin','foot')}
    parts = {}
    for part in layout['parts']:
        bone=part['bone']
        if bone not in bones: continue
        image=np.asarray(Image.open(case/part['file']).convert('RGBA'))[...,3]>0
        y,x=np.nonzero(image)
        parts[part['name']] = (bone, np.column_stack((x+.5,y+.5)))
    records=[]
    for row in rows:
        if row['kind']!='presented':continue
        posed={}
        for name,(bone,xy) in parts.items():
            t=matrix(row['parts'][name]['transform'])
            posed.setdefault(bone,[]).append((xy[:,0,None]*t[None,:2,0]+xy[:,1,None]*t[None,:2,1]+t[None,:2,2],t[:2,:2]))
        for side in sides:
            for first,second in (('thigh_','shin_'),('shin_','foot_')):
                distance=min(gap(a,ab,b,bb) for a,ab in posed[first+side] for b,bb in posed[second+side])
                records.append({'joint':view_tag(layout,row,second+side),'air_px':distance})

    return records


def view_tag(layout,row,joint):
    return f'{layout["facing"]}/move/frame {row["frame"]}/{joint}'


def support_report(layout,data,samples):
    """Walk plus unchanged non-move planted supports, shared by both cases."""
    result=report(layout,data,samples)
    result['errors']=[e for e in result['errors'] if 'knee' not in e and 'swing lift' not in e]
    result['jab']=[]
    from .leg_roles import resolve_bone
    anatomy=for_layout(layout)
    previous={}
    for row in samples['samples']:
        if row['view']!=layout['facing'] or row['clip'] in ('move','death','idle'):continue
        for source in anatomy['planted_bones']:
            foot=resolve_bone(source,anatomy,layout['facing'])
            rest=np.asarray(layout['joints'][foot]['position'])
            actual=np.asarray(row['bones'][foot]['global'][4:])
            actual=rest+np.rint(actual-rest) if row['kind']=='presented' else actual
            error=float(np.linalg.norm(actual-rest))
            key=(row['clip'],foot,row['kind'])
            old=previous.get(key)
            change=float(np.linalg.norm(actual-old['actual'])) if old is not None and row['kind']=='presented' and row['frame']==old['frame']+1 else 0.
            record={'kind':row['kind'],'clip':row['clip'],'side':foot.removeprefix('foot_'),'frame':row['frame'],'target_error_px':error,'frame_change_px':change}
            result['jab'].append(record)
            if error > (TARGET_TOLERANCE_PX if row['kind']=='presented' else anatomy.get('planted_tolerance_px',EPSILON))+EPSILON:
                result['errors'].append(f'{layout["facing"]}/{row["clip"]}/{record["side"]}/frame {row["frame"]}: support target error {error:.6f} px')
            if change!=0.:result['errors'].append(f'{layout["facing"]}/{row["clip"]}/{record["side"]}/frame {row["frame"]}: stance moved {change:.6f} px')
            previous[key]={'frame':row['frame'],'actual':actual}
    result['maximum_jab_frame_change_px']=max((r['frame_change_px'] for r in result['jab']),default=0.)
    result['maximum_jab_target_error_px']=max((r['target_error_px'] for r in result['jab']),default=0.)
    result['maximum_target_error_px']=max(result['maximum_stance_target_error_px'],result['maximum_jab_target_error_px'])
    result['maximum_frame_change_px']=max(result['maximum_stance_frame_change_px'],result['maximum_jab_frame_change_px'])
    result['ok']=not result['errors']
    return result


def summary(report):
    """Retain results, extrema, swings and failures, without overlapping frames."""
    frame_fields=('frames','stance','rigid_air','jab')
    result={key:value for key,value in report.items() if key not in frame_fields}
    result['sample_counts']={key:len(report[key]) for key in frame_fields if key in report}
    result['rigid_air_failures']=[row for row in report.get('rigid_air', [])
                                  if row['air_px'] > MAX_RIGID_AIR_PX + EPSILON]
    return result


def write_reports(case, name, reports):
    """Shared writer: tracked summaries; full frames in gitignored proof logs."""
    from cutout_pipeline.cases import write_json
    proof=Path(case)/'proof'
    write_json(proof/(name+'.json'),{view:summary(report) for view,report in reports.items()})
    write_json(proof/'logs/walk_gates'/(name+'.json'),reports)
