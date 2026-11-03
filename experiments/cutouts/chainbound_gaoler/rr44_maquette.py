"""Front-only pose fit; rear joints are the same body's proper half turn.

No delivery is certified without the director's Blender bridge captures.
Landmarks trace the approved wrist/elbow and chain grip, not motion tuning.
"""
from copy import deepcopy
import numpy as np
from rr44_case import PROJECT, CASE, JOBS, VIEWS
from cutout_pipeline.cases import read_json, write_json, digest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from maquette_cutout import projected

FOLDER = PROJECT/'spec/art_identity/maquettes/chainbound_gaoler'
FRONT_LANDMARKS = {'elbow_far': [106, 110], 'hand_far': [94, 137]}
GRIPS = {'front': [89, 145], 'rear': [170, 162]}
FIT_NUMERICS = {'shoulder_trace_min_x': 107, 'shoulder_search_step_px': .25, 'bend_epsilon_deg': .0001}


def rigid(a, b, start, end):
    u, v = b-a, end-start
    u, v = u/np.linalg.norm(u), v/np.linalg.norm(v)
    axis = np.cross(u, v); sine = np.linalg.norm(axis); cosine = u@v
    rotation = np.eye(3)
    if sine > 1e-12:
        k = np.array([[0,-axis[2],axis[1]],[axis[2],0,-axis[0]],[-axis[1],axis[0],0]])
        rotation += k+k@k*((1-cosine)/(sine*sine))
    result = np.eye(4); result[:3,:3] = rotation; result[:3,3] = start-rotation@a
    return result


def fit():
    recipe = read_json(FOLDER/'measurements.json')
    original = compile_recipe(recipe)
    recipe = deepcopy(recipe)
    for view, (_, new) in VIEWS.items():
        recipe['sources'][view] = str((JOBS/new/'processed.png').relative_to(PROJECT))
        recipe['source_sha256'][view] = digest(JOBS/new/'processed.png')
    # One source-to-native registration, inherited from mq-15. No rear fit.
    registration = read_json(FOLDER/'delivery/mq15_acceptance.json')['front_fit']['views']
    scale = 255/1024
    origin = np.asarray(projected(original, [0,0,0], 'front'))*scale
    basis = np.stack([np.asarray(projected(original, axis, 'front'))*scale-origin for axis in np.eye(3)], axis=1)
    joints = {n: np.asarray(p) for n,p in original['joints'].items()}
    target = dict(joints)
    null=np.linalg.svd(basis)[2][-1]
    def sphere_candidates(point, centre, radius):
        delta=point-centre;along=delta@null
        discriminant=radius*radius-float(delta@delta)+along*along
        if discriminant < 0: return []
        return [point+null*(-along+sign*np.sqrt(discriminant)) for sign in (-1,1)]
    planes={}
    for name, point in FRONT_LANDMARKS.items():
        old = np.asarray(projected(original, joints[name], 'front'))*scale+registration['front']['translation_px']
        planes[name] = joints[name]+np.linalg.pinv(basis)@(np.asarray(point)-old)
    def signed_bend(a,b,c,view):
        a,b,c=[np.asarray(projected(original,p,view)) for p in (a,b,c)]
        u,v=b-a,c-b
        return np.degrees(np.arctan2(u[0]*v[1]-u[1]*v[0],u@v))*(1 if view=='front' else -1)
    # Fit only the front trace. The near shoulder stays fixed; the far
    # shoulder retains its exact 3D level and the mq-15 projected rise rule.
    # Among depth solutions retain only anatomically valid elbows in both
    # views of the same body. No rear landmark or independent pose is fitted.
    front_shoulder=np.asarray(projected(original,joints['shoulder_far'],'front'))*scale+registration['front']['translation_px']
    near=np.asarray(projected(original,joints['shoulder_near'],'front'))*scale+registration['front']['translation_px']
    candidates=[]
    for x in np.arange(front_shoulder[0],FIT_NUMERICS['shoulder_trace_min_x']-FIT_NUMERICS['shoulder_search_step_px'], -FIT_NUMERICS['shoulder_search_step_px']):
        desired=np.array([x,near[1]-.15*abs(near[0]-x)])
        shoulder=joints['shoulder_far'].copy();shoulder[:2]+=np.linalg.solve(basis[:,:2],desired-front_shoulder)
        for elbow in sphere_candidates(planes['elbow_far'],shoulder,np.linalg.norm(joints['elbow_far']-joints['shoulder_far'])):
            for hand in sphere_candidates(planes['hand_far'],elbow,np.linalg.norm(joints['hand_far']-joints['elbow_far'])):
                if all(signed_bend(shoulder,elbow,hand,v)>=-FIT_NUMERICS['bend_epsilon_deg'] for v in ('front','rear')):
                    candidates.append((np.linalg.norm(shoulder-joints['shoulder_far'])**2+np.linalg.norm(elbow-joints['elbow_far'])**2+np.linalg.norm(hand-joints['hand_far'])**2,shoulder,elbow,hand))
    if not candidates: raise ValueError('No unscaled, level-shoulder pose fits the front trace with legal elbows')
    _,target['shoulder_far'],target['elbow_far'],target['hand_far']=min(candidates,key=lambda r:r[0])
    fore_matrix=rigid(joints['elbow_far'],joints['hand_far'],target['elbow_far'],target['hand_far'])
    gloves = ['glove_far','grip_finger_1','grip_finger_2','grip_finger_3','grip_finger_4','grip_thumb']
    pieces={p['id']:p for p in original['pieces']}
    old_grip=np.mean(pieces['chain_link_1']['path'],axis=0)
    from PIL import Image
    from rr44_case import BASE,STAGED
    from rr44_partition import cut
    paint=np.asarray(Image.open(JOBS/VIEWS['front'][1]/'processed.png').convert('RGBA'))
    region=np.asarray(Image.open(STAGED/'front_r1_region.png').convert('L'))>0
    hand_source=cut(BASE,read_json(BASE/'layouts/front.json'),paint,region)['hand_far'][...,3]>0
    from rr44_maquette_grip import fit as fit_grip
    hand_matrix,new_grip,grip_fit=fit_grip(original,gloves,joints['hand_far'],target['hand_far'],old_grip,GRIPS['front'],
                                         basis,origin+registration['front']['translation_px'],hand_source,rigid,sphere_candidates)
    target['hand_tip_far']=(hand_matrix@np.append(joints['hand_tip_far'],1))[:3]
    pose = recipe['surface_pose']
    for name in FRONT_LANDMARKS | {'shoulder_far': [], 'hand_tip_far': []}:
        pose['joint_offsets_m'][name] = (np.asarray(pose['joint_offsets_m'][name])+target[name]-joints[name]).tolist()
    arm_groups = [('upper_far_gambeson','shoulder_far','elbow_far'), ('fore_far_gambeson','elbow_far','hand_far')]
    for piece,a,b in arm_groups:
        pose['operations'].append(dict(pieces=[piece], matrix=rigid(joints[a],joints[b],target[a],target[b]).tolist()))
    move = hand_matrix.copy()
    pose['operations'].append(dict(pieces=gloves,matrix=move.tolist()))
    frame=deepcopy(recipe['mq15']['grip_frame'])
    frame['origin']=(hand_matrix@np.append(frame['origin'],1))[:3].tolist()
    for key,axis in [('finger_axis',frame['finger_axis']),('knuckle_normal',frame['knuckle_normal']),('up_axis',[0,0,1])]:
        frame[key]=(hand_matrix[:3,:3]@axis).tolist()
    pose['grip_frame']=frame
    # Fit chain projection by rotation into depth, retaining native lengths.
    # An axial half turn reverses the hook's point without a reflection.
    chain = [p['id'] for p in original['pieces'] if p['part']=='chain']
    old_hook=np.mean(pieces['iron_hook']['path'],axis=0)
    old_projection=np.asarray(projected(original,old_hook,'front'))*scale+registration['front']['translation_px']
    hook_plane=old_hook+np.linalg.pinv(basis)@(np.array([84,204])-old_projection)
    new_hook=min(sphere_candidates(hook_plane,new_grip,np.linalg.norm(old_hook-old_grip)),key=lambda p:np.linalg.norm(p-old_hook))
    move=rigid(old_grip,old_hook,new_grip,new_hook)
    axis=(new_hook-new_grip)/np.linalg.norm(new_hook-new_grip)
    twist=np.eye(4);twist[:3,:3]=2*np.outer(axis,axis)-np.eye(3);twist[:3,3]=new_grip-twist[:3,:3]@new_grip
    move=twist@move
    pose['operations'].append(dict(pieces=chain,matrix=move.tolist()))
    correction_path=CASE.parent/'rr44_feedback1_maquette_fit.json'
    if correction_path.exists():
        from spec.art_identity.maquettes.blender.contract import digest as spec_digest
        correction=read_json(correction_path)
        for correction in [correction,*correction.get('followups',[])]:
            if spec_digest(compile_recipe(recipe))!=correction['input_spec_hash']:
                raise ValueError('Native centroid correction is bound to a different maquette')
            error=np.asarray(correction['centroid_offset_px'])
            goal=correction['centroid_limit_px']-correction['centroid_quantization_guard_px']
            delta=-error*max(0.,1-goal/np.linalg.norm(error))
            matrix=np.eye(4);matrix[:3,3]=np.linalg.pinv(basis)@delta
            pose['operations'].append(dict(pieces=[correction['piece']],matrix=matrix.tolist()))
    output = CASE/'maquette'; output.mkdir(parents=True,exist_ok=True)
    write_json(output/'measurements.json',recipe)
    write_json(output/'grip_fit.json',grip_fit)
    spec = compile_recipe(recipe)
    write_json(output/'spec_native.json',spec)
    # Project the same native body for both views, preserving the certified
    # translation until the new silhouette has actually been captured.
    projected_joints = {view:{name:(np.asarray(projected(spec,p,view))*scale+registration[view]['translation_px']).tolist()
                             for name,p in spec['joints'].items()} for view in ('front','rear')}
    write_json(output/'joints_source_px.json',projected_joints)
    status_path=output/'fit_status.json';status=read_json(status_path) if status_path.exists() else {}
    from spec.art_identity.maquettes.blender.contract import digest as spec_digest
    acceptance=output/'delivery/mq15_acceptance.json'
    verified=(status.get('native_verified') and status.get('spec_hash')==spec_digest(spec) and acceptance.exists()
              and status.get('acceptance_sha256')==digest(acceptance))
    if not verified:
        write_json(status_path,dict(native_verified=False, bridge='director-managed; inspect the current native run',
                   source_landmarks=FRONT_LANDMARKS, rear_policy='proper half turn diag(-1,-1,1); no independent pose or mirror',
                   joints_source_px=projected_joints, acceptance='pending native IoU >= .82 and every semantic centroid <= 5 px'))
    print('RR44 MAQUETTE: PREPARED (front fitted joints; proper half-turn rear; native acceptance pending bridge)')
    return projected_joints


if __name__ == '__main__': fit()
