"""Opt-in mq-19 compiler; never rewrites historical owner inputs or delivery."""
from copy import deepcopy
import json
from pathlib import Path
import numpy as np

from spec.art_identity.maquettes.blender.contract import validate, todos,digest
from spec.art_identity.maquettes.blender.curate_delivery import write
from ..recipe import compile_spec as mq17_spec, FOLDER as BASE
from ..forms import cord
from .pose import solve, alignment, rotation, staff_frame
from .cloth import panel,closed_surface
from .shape_reference import encode as encode_shape_reference

FOLDER = Path(__file__).resolve().parent
PROOF_CAMERA={'canvas_px':1088,'reference_canvas_px':1024}


def design():
    return json.loads((FOLDER/'design.json').read_text())


def pose_spec(data=None):
    """Diagnostic pose only. Missing cloth is explicit; cannot be delivered."""
    data = deepcopy(data or design()); baseline = mq17_spec(); spec = deepcopy(baseline)
    j, frames, thigh = solve(baseline, data['pose'], data.get('pose_resolution')); old = {k:np.asarray(v) for k,v in baseline['joints'].items()}
    H, L = (baseline['mq17'][k] for k in ('height_m','leg_length_m'))
    old_hips = (old['hip_near']+old['hip_far'])/2
    hips = (j['hip_near']+j['hip_far'])/2
    transformed = []
    for piece in spec['pieces']:
        name = piece['id']; part = piece['part']; pivot = piece['rig_pivot_joint']
        if name in ('near_cloak_streamer','front_tabard','tabard_sigils'):
            continue
        points = np.asarray(piece['vertices'])
        if part=='staff': continue
        if part=='head': origin,target,r = old['head'],j['head'],frames['head']
        elif part in ('pelvis','sash'): origin,target,r = old_hips,hips,frames['pelvis']
        elif part in ('torso','bell'): origin,target,r = old_hips,hips,frames['torso']
        elif part.startswith('pauldron_'):
            origin,target,r = old[pivot],j[pivot],frames['torso']
        else:
            bone = next(b for b in spec['armature']['bones'] if b['name']==piece['rig_bone'])
            a,b = bone['head'],bone['tail']; origin,target = old[a],j[a]
            # Sabatons remain on the sole plane; feet are translated only.
            r = np.eye(3) if part.startswith('foot_') else alignment(old[b]-old[a],j[b]-j[a])
        piece['vertices'] = (target+np.einsum('nj,kj->nk',points-origin,r)).tolist(); transformed.append(piece)
    # Long fingers retain mq-17 section lengths and diameters, curl is directed.
    transformed = [p for p in transformed if not p['id'].startswith('finger_near_')]
    for finger in range(4):
        original = next(p for p in baseline['pieces'] if p['id']=='finger_near_'+str(finger))
        rings = np.asarray(original['vertices']).reshape(-1,12,3).mean(1)
        point = j['hand_near']+frames['torso']@(rings[0]-old['hand_near']); path = [point.copy()]
        for k,length in enumerate(np.linalg.norm(np.diff(rings,axis=0),axis=1)):
            a = np.radians(k*data['pose']['near_knuckle_degrees'])
            point = point+frames['torso']@np.array([np.sin(a),0,-np.cos(a)])*length; path.append(point.copy())
        transformed.append(cord(original['id'],'hand_near','hand_near',np.asarray(path).tolist(),
                                baseline['feedback1']['finger_diameter']*H/2))
    # Retain the complete fork, tapered tine meshes, pennant and sigils under
    # one rigid transform. The shaft's bottom ring is the sole-plane contact.
    r = staff_frame(data['pose']); grip = j['hand_far']; old_grip = old['hand_far']
    source_staff = next(p for p in baseline['pieces'] if p['id']=='staff')
    a,b = baseline['mq17']['staff_components']['shaft']
    shaft = np.asarray(source_staff['vertices'][a:b]).reshape(-1,12,3).mean(1)
    delta = r[:,2]; butt = grip-delta*(grip[2]/delta[2])
    base = butt+delta*((shaft[-1,2]-shaft[0,2])/delta[2])
    # Preserve the approved fork/pennant assembly at its fork root. Only the
    # shaft endpoint follows the newly directed grounded grip line.
    old_base = np.asarray(baseline['mq17']['staff']['fork_base'])
    for source in (p for p in baseline['pieces'] if p['part']=='staff'):
        piece = deepcopy(source); points = np.asarray(source['vertices'])
        piece['vertices'] = (base+np.einsum('nj,kj->nk',points-old_base,r)).tolist()
        if piece['id']=='staff':
            count = 12; moved = np.asarray(piece['vertices'])
            moved[a:a+count] = butt+np.einsum('nj,kj->nk',points[a:a+count]-shaft[0],r)
            moved[a:a+count] -= np.outer(moved[a:a+count,2]/delta[2],delta)
            moved[a+count:b] = base+np.einsum('nj,kj->nk',points[a+count:b]-shaft[-1],r)
            piece['vertices'] = moved.tolist()
        transformed.append(piece)
    spec['pieces'] = transformed; spec['joints'] = {k:v.tolist() for k,v in j.items()}
    spec['native_features']['spine_ridge']['visibility'].pop('rear',None)
    # Rear shoulder/collar exposure is audited by region in mq19.occlusion.
    # The prior cloak does not survive as a torso/limb-owned impostor.
    spec['native_features']['tabard_sigils']['visibility']['rear'] = 'occluded'
    spec['mq19'] = {'design':data, 'gauge_H_m':H, 'gauge_L_m':L,
        'bone_forward':{k:r[:,0].tolist() for k,r in frames.items()},
        'baseline_shape_reference':encode_shape_reference(baseline),
        'baseline_proportions':json.loads((BASE/'delivery/native_probe.json').read_text())['proportions'],
        'staff_butt':butt.tolist(), 'staff_fork_base':base.tolist(),
        'diagnostic_only':True,'capture_px':PROOF_CAMERA['canvas_px'],
        'reference_ortho_scale':baseline['ortho_scale']}
    spec['delivery_reports'] = ['mq19_native.json','mq19_acceptance.json']
    frame_spec(spec)
    return spec


def frame_spec(spec):
    # Preserve metres per pixel while enlarging only the transparent proof
    # canvas. The directed staff/body span is 1031px and cannot fit 1024px.
    from spec.art_identity.maquettes.raster import camera
    _,_,basis,_=camera(spec)
    scale=spec['mq19']['reference_ortho_scale']*PROOF_CAMERA['canvas_px']/PROOF_CAMERA['reference_canvas_px']
    spec['ortho_scale']=scale
    vertices=np.concatenate([p['vertices'] for p in spec['pieces']])
    for view in ('front','rear'):
        transform=spec['view_transforms'][view];transform['ortho_scale']=scale
        matrix=np.asarray(transform['object_to_world'])[:3,:3]
        projected=np.einsum('nj,kj->nk',np.einsum('nj,kj->nk',vertices,matrix),basis[:2])
        centre=(projected.min(0)+projected.max(0))/2
        transform['target']=(basis[0]*centre[0]+basis[1]*centre[1]).tolist()


def compile_spec(data=None):
    data = deepcopy(data or design())
    missing = todos(data, 'mq19.design')
    if missing: raise ValueError('Unresolved design: '+'; '.join(missing))
    spec = pose_spec(data); H = spec['mq19']['gauge_H_m']; d = data['cloak']
    if 'vertices_over_H' in d['surface']:
        generated_layout=d['surface']['layout'];wrap=np.asarray(generated_layout['wrap_frame'])
        seam_normals={i:direction for i,direction in zip(generated_layout['shoulder_indices'],generated_layout['attachment_normals'])}
        piece,layout = closed_surface('full_back_cloak','cloak','torso',
            np.asarray(d['surface']['vertices_over_H'],float)*H,d['surface']['faces'],d['thickness_over_H']*H,
            horizontal_tips=[v['tip_index'] for v in d['surface']['layout']['strips']],edge_normals=seam_normals)
        layout.update(d['surface']['layout'])
    else:
        rows = np.asarray(d['surface']['rows_over_H'],float)*H
        piece,layout = panel('full_back_cloak','cloak','torso',rows,
                             spec['feedback1']['cloth_min_thickness']*H,d['removed_quads'])
    spec['pieces'].append(piece); spec['mq19']['cloak_layout'] = layout
    # Only the tabard's final row changes; all upper folds, sigils and width
    # retain the approved surface. The hem vector contains authored grid Zs.
    baseline = mq17_spec(); tabard = deepcopy(next(p for p in baseline['pieces'] if p['id']=='front_tabard'))
    nr,nc = baseline['volume_layout']['tabard_grid']; count = nr*nc
    old = np.asarray(tabard['vertices']); mid = ((old[:count]+old[count:])/2).reshape(nr,nc,3)
    hem = np.asarray(data['tabard']['hem_z_over_H'],float)*H
    if hem.shape!=(nc,) or not np.isfinite(hem).all(): raise ValueError('Tabard hem requires one finite Z per inherited column')
    mid[-1,:,2] = hem
    for offset in (0,count):
        start = offset+(nr-1)*nc
        old[start:start+nc,2] += hem-((np.asarray(tabard['vertices'])[:count]+np.asarray(tabard['vertices'])[count:])/2).reshape(nr,nc,3)[-1,:,2]
    tabard['vertices'] = old.tolist()
    # Tabard and its unchanged sigils follow the pelvic frame together.
    approved = {k:np.asarray(v) for k,v in baseline['joints'].items()}
    j = {k:np.asarray(v) for k,v in spec['joints'].items()}
    before = (approved['hip_near']+approved['hip_far'])/2; after = (j['hip_near']+j['hip_far'])/2
    r = rotation([1,0,0],-data['pose']['pelvis_down_near_degrees'])
    for source in (tabard,next(p for p in baseline['pieces'] if p['id']=='tabard_sigils')):
        piece = deepcopy(source); piece['vertices'] = (after+np.einsum('nj,kj->nk',np.asarray(piece['vertices'])-before,r)).tolist()
        spec['pieces'].append(piece)
    if 'vertices_over_H' in d['surface']:
        spec['mq19']['design']['cloak']['surface']={'generated_mesh_sha256':digest(d['surface'])}
        spec['mq19']['design']['cloak']['removed_quads']={'count':len(d['removed_quads']),'sha256':digest(d['removed_quads'])}
    spec['mq19']['diagnostic_only'] = False
    frame_spec(spec)
    validate(spec)
    return spec


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--pose-only',action='store_true',help='Diagnostic JSON, never a build input')
    args = parser.parse_args()
    result = pose_spec() if args.pose_only else compile_spec()
    write(args.out,result)
    print('MQ19_SPEC: '+('DIAGNOSTIC_ONLY' if args.pose_only else 'PASS')+'; '+str(args.out))


if __name__=='__main__': main()
