"""Pure geometry observations shared by the bridge probe and focused tests."""
import numpy as np

GEOMETRY_PROOF_DEFAULTS = {'hem_prominence_m':.005, 'finger_cross_samples':16,
    'upper_link_depth_below_grip_m':.028, 'link_envelope_slack_m':.004,
    'thumb_minimum_overlap_m':.01, 'thumb_maximum_gap_m':.035}


def hem_tip_count(down, prominence):
    """Count ragged points, including pointed corners, ignoring flat samples."""
    a=np.asarray(down,float)
    # Collinear subdivisions are not extra cloth points.
    slope=np.diff(a);indices=([0] if a[0]>a[1] else [])+[i for i in range(1,len(a)-1)
        if slope[i-1]>0 and slope[i]<0]+([len(a)-1] if a[-1]>a[-2] else [])
    count=0
    for i in indices:
        left=a[:i+1].min();right=a[i:].min()
        amount=(a[i]-right if i==0 else a[i]-left if i==len(a)-1 else min(a[i]-left,a[i]-right))
        if amount>=prominence:count+=1
    return count



def thumb_contact_passed(overlap,gap):
    return bool(overlap[0]>=GEOMETRY_PROOF_DEFAULTS['thumb_minimum_overlap_m'] and
                overlap[2]>=GEOMETRY_PROOF_DEFAULTS['thumb_minimum_overlap_m'] and
                gap<=GEOMETRY_PROOF_DEFAULTS['thumb_maximum_gap_m'])


def grip_observation(spec, points, frame):
    origin=np.asarray(frame['origin']);wide=np.asarray(frame['finger_axis']);normal=np.asarray(frame['knuckle_normal'])
    names=['grip_finger_'+str(i) for i in range(1,5)]
    expected=names+['grip_thumb','glove_far']
    available=all(n+'_render' in points for n in expected+['chain_link_1'])
    if not available:return {'passed':False,'checks':{'complete_gloved_grip':False}}
    # A reposed grip owns its complete orthonormal frame. Preserve the exact
    # historical world-Z arithmetic when no optional up axis is supplied.
    height=lambda delta:(delta*np.asarray(frame['up_axis'])).sum(axis=1) if 'up_axis' in frame else delta[:,2]
    local=lambda values:np.stack((((values-origin)*wide).sum(axis=1),((values-origin)*normal).sum(axis=1),height(values-origin)),axis=-1)
    geometry={n:local(np.asarray(points[n+'_render'])) for n in expected}
    palm_front=float(geometry['glove_far'][:,1].max())
    fingers_front={n:float(geometry[n][:,1].max()) for n in names}
    thumb=geometry['grip_thumb'];thumb_front=float(thumb[:,1].max())
    pieces={p['id']:p for p in spec['pieces']}
    curls={}
    for name in names:
        # The native closed-sweep topology stores one ring per station. Its
        # ring means recover the centreline from the opened mesh, not the recipe.
        vertices=geometry[name];samples=GEOMETRY_PROOF_DEFAULTS['finger_cross_samples']
        valid=len(vertices)>=2*samples and len(vertices)%samples==0
        path=vertices.reshape(-1,samples,3).mean(1) if valid else np.zeros((1,3))
        curls[name]=bool(valid and path[0,2]>0 and path[-1,1]<0 and path[:,2].min()<0 and path[:,1].max()>0)
    fingers=np.concatenate([geometry[n] for n in names])
    overlap=np.minimum(thumb.max(0),fingers.max(0))-np.maximum(thumb.min(0),fingers.min(0))
    # AABB overlap alone can bridge empty space. Bound the closest actual
    # native vertex gap as well as lateral and vertical interval overlap.
    gap=float(np.linalg.norm(thumb[:,None,:]-fingers[None,:,:],axis=2).min())
    thumb_contact=thumb_contact_passed(overlap,gap)
    all_hand=np.concatenate(list(geometry.values()))
    link=local(np.asarray(points['chain_link_1_render']))
    upper=link[link[:,2]>=-GEOMETRY_PROOF_DEFAULTS['upper_link_depth_below_grip_m']]
    slack=GEOMETRY_PROOF_DEFAULTS['link_envelope_slack_m']
    inside=bool(len(upper) and np.all(upper>=all_hand.min(0)-slack) and np.all(upper<=all_hand.max(0)+slack))
    checks={'complete_gloved_grip':available,'four_wrapped_fingers':all(curls.values()),
            'knuckles_forward_of_palm':all(v>palm_front for v in fingers_front.values()),
            'thumb_over_fingers':thumb_front>max(fingers_front.values()) and thumb_contact,
            'top_link_in_grip_envelope':inside,
            'correct_hand_ownership':all(pieces[n]['part']=='hand_far' for n in expected)}
    return {'passed':all(checks.values()),'checks':checks,'finger_curls':curls,
            'palm_front_m':palm_front,'knuckle_front_m':fingers_front,'thumb_front_m':thumb_front,
            'thumb_lateral_overlap_m':float(overlap[0]),'thumb_vertical_overlap_m':float(overlap[2]),
            'thumb_nearest_finger_gap_m':gap,'upper_link_samples_in_envelope':len(upper),
            'definition':'Opened native finger rings recover four curled centrelines; native knuckles face forward. The native thumb overlaps the finger group laterally and vertically with a bounded vertex gap. Native top-link vertices in the upper grip band lie inside the hand envelope. This is an envelope/pose check, not a collision-clearance claim.'}


def native_mesh_binding(objects,report):
    """Use precisely the builder's world-coordinate, face-order, owner hash."""
    from spec.art_identity.maquettes.blender.contract import mesh_hash,digest
    hashes={o.name:mesh_hash([list(o.matrix_world@v.co) for v in o.data.vertices],
                            [list(p.vertices) for p in o.data.polygons],o['part']) for o in objects}
    combined=digest(hashes);expected=report.get('mesh_hashes',{})
    mismatches=sorted(set(hashes)^set(expected)|{n for n in hashes if hashes[n]!=expected.get(n)})
    return {'native_mesh_hash':combined,'mismatches':mismatches,
            'passed':combined==report['combined_mesh_hash'] and hashes==expected}
