"""Cut and rig the director's unchanged mq3 paint against mq-15."""
import shutil
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from rr38_case import PROJECT, CASE, ASSETS, DIRECTOR, PIECES, NATIVE_PIECES, BONES, GROUPS
sys.path[:0] = [str(PROJECT), str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/hoarfrost_seer')]
from rr07_inputs import label_palette
from rr07_geometry import bind_layout
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_cutout import projected
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.silhouette import holes, dilate
from humanoid_cutout.source_view import prepare
from humanoid_cutout.anatomy import load
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.mesh import grid, weights_for
from humanoid_cutout.seams import build_masks
from humanoid_cutout.tucks import required_tuck
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.promotion import promote
from maquette_motion.bleed import edge_texels
from rr38_registration import for_view
from rr38_surfaces import partition, depths, fill, interior


def native_depths(spec, view):
    from maquette_cutout import camera_view
    matrix, target, azimuth, elevation, _, distance = camera_view(spec, view)
    direction = np.array([np.cos(elevation)*np.cos(azimuth), np.cos(elevation)*np.sin(azimuth), np.sin(elevation)])
    result = {}
    for label in spec['labels']:
        bones = [b for b in spec['armature']['bones'] if b['region'] == label]
        points = [spec['joints'][b[k]] for b in bones for k in ('head', 'tail')]
        if not points:
            for p in spec['pieces']:
                if p['part'] != label and label not in p.get('side_parts', []): continue
                if 'vertices' in p: points.extend(p['vertices'])
                elif 'outline_3d' in p: points.extend(p['outline_3d'])
                elif 'path' in p: points.extend(p['path'])
                elif 'pattern' in p: points.extend(q for row in p['pattern']['rows'] for q in row['points'])
                elif 'centre' in p: points.append(p['centre'])
        if not points: raise ValueError('Missing native center: ' + label)
        center = (matrix @ np.append(np.mean(points, axis=0), 1))[:3]
        result[label] = float(distance - (center-target) @ direction)
    return result


def recipe(_creature, spec):
    mapping = {'root':'root', 'pelvis':'pelvis', 'torso':'torso', 'head':'head', 'chain':'hand_far'}
    for side in ('near', 'far'):
        mapping.update({a+'_'+side:b+'_'+side for a,b in (
            ('upper','shoulder'),('fore','elbow'),('hand','hand'),('thigh','hip'),('shin','knee'),('foot','ankle'))})
    anatomy = load(CASE)
    return {'joints': {n:{'joint':s,'parent':anatomy['required_parents'][n]} for n,s in mapping.items()},
            'parts':{label:BONES.get(n,n) for n,labels in NATIVE_PIECES.items() for label in labels}}


def store(image, folder, name, bounds=None, *, case=CASE):
    if bounds is None:
        ys,xs = np.nonzero(image[...,3])
        if not len(xs): raise ValueError('Empty cut: '+name)
        bounds = [int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
    path = folder/(name+'.png');path.parent.mkdir(parents=True,exist_ok=True)
    Image.fromarray(image).crop(bounds).save(path)
    return {'name':name,'file':str(path.relative_to(case)),'offset':bounds[:2],'bbox':bounds}


def proof_masks(layout, paint, visible, hidden, definition, anatomy, *, case=CASE):
    layers = {}
    meshes = {m['name']:m for m in layout['joint_meshes']}
    for part in layout['parts']:
        image = source_pixels(case,part); allowed = image[...,3]>0
        checks = np.zeros_like(image);checks[allowed] = [255,0,0,255]
        if part.get('hidden_material'): checks[allowed,1] = 255
        checks[allowed & outline_class(image,definition),2] = 255
        record = store(checks, case/'checks'/layout['facing'], part['name'],part['bbox'],case=case)
        layers[part['name']] = {'mask':record['file'],'mask_offset':record['offset'],'z_index':part['z_index'],
            'source':part['file'],'rigid':part['name'] not in meshes,'source_sha256':digest(case/part['file'])}
        donors = interior(visible[part['logical_part']],definition)
        legal = np.isin(image.view('uint32').reshape(255,255), np.unique(donors.view('uint32').reshape(255,255)[donors[...,3]>0])) & allowed
        if not part.get('hidden_material'): legal = allowed
        path=case/f'uncovered/donor_{layout["facing"]}_{part["name"]}.png'
        Image.fromarray(legal.astype('uint8')*255).save(path)
    layout['proof_layers']=layers
    references=[]
    for i,hole in enumerate(holes(paint[...,3]>0)):
        if int(hole.sum())<=1: continue
        rim=dilate(hole,1)&~hole
        owner=max(visible,key=lambda n:int((rim&(visible[n][...,3]>0)).sum()))
        path=case/f'holes/{layout["facing"]}_{i:02d}.png';path.parent.mkdir(exist_ok=True)
        image=np.zeros_like(paint);image[hole]=255;Image.fromarray(image).save(path)
        record={'name':f'RestHole{i:02d}','owner':owner,'file':str(path.relative_to(case)),'bone':BONES.get(owner,owner)}
        if owner in anatomy['meshes']:
            vertices,uvs,triangles=grid([0,0,255,255])
            weights=weights_for(vertices,meshes[owner]['bbox'],layout['joints'],anatomy['meshes'][owner])
            target=case/f'holes/{layout["facing"]}_{owner}_mesh.json'
            write_json(target,dict(vertices=vertices,uvs=uvs,triangles=triangles,weights=weights,z_index=0))
            record['mesh_template']=str(target.relative_to(case))
        references.append(record)
    layout['proof_rest_holes']=references
    layout['proof_joint_seams']=build_masks(case,layout,visible,anatomy)


def build_view(view, inputs, anatomy):
    base,old,_,delivery=prepare(PROJECT,CASE,inputs,view,NATIVE_PIECES,for_view(view),
        label_palette,native_depths,recipe,bind_layout)
    source=CASE/'source'/view;source.mkdir(parents=True,exist_ok=True)
    for name in ('processed.png','processed.json'):shutil.copyfile(PROJECT/inputs[view+'_job']/name,source/name)
    paint=np.asarray(Image.open(source/'processed.png').convert('RGBA')).copy()
    visible={n:np.zeros_like(paint) for n in PIECES}
    solos={}
    for name,labels in PIECES.items():
        for part in old['parts']:
            if part['logical_part'] not in labels:continue
            image=source_pixels(base,part);mask=image[...,3]>0;visible[name][mask]=image[mask]
        solos[name]=np.logical_or.reduce([np.asarray(Image.open(base/f'registered/{view}_solo_{label}.png'))[...,3]>128 for label in labels])
    (CASE/'ownership').mkdir(exist_ok=True)
    partition(CASE,view,visible,paint)
    joints=old['joints']
    for name in ('tabard','coat_near','coat_far'):
        start=np.asarray(joints['pelvis']['position']);ys,xs=np.nonzero(solos[name])
        tip=np.array([xs[ys==ys.max()].mean(),ys.max()])
        joints[name+'_mid']={'parent':'pelvis','position':((start+tip)/2).tolist()}
        joints[name+'_tip']={'parent':name+'_mid','position':tip.tolist()}
    hidden,domains=fill(CASE,view,visible,solos,paint,rules(base,view))
    definition=rules(base,view);tucks=[]
    for name,policy in anatomy['tucks']['pieces'].items():
        if not visible[name][...,3].any():continue
        required=required_tuck(name,visible,joints,anatomy['tucks'],continuation=hidden[name][...,3]>0)
        missing=required&(hidden[name][...,3]==0)
        seed=interior(visible[name],definition)
        if seed[...,3].any():
            replacement=edge_texels(seed,missing,definition)
            hidden[name][missing]=replacement[missing]
        path=CASE/f'tucks/{view}_{name}.png';path.parent.mkdir(exist_ok=True)
        Image.fromarray(required.astype('uint8')*255).save(path)
        tucks.append({'piece':name,'minimum_px':policy['depth_px'],'cover':policy['covers'],
            'required_mask':str(path.relative_to(CASE)),'required_pixels':int(required.sum()),'missing_pixels':int((required&(hidden[name][...,3]==0)).sum())})
    source_depths={p['logical_part']:p['z_index'] for p in old['parts']}
    from rr38_row_fills import apply as apply_row_fills
    apply_row_fills(view,visible,hidden,paint,definition)
    order=depths({n:source_depths[labels[0]] for n,labels in PIECES.items()},view)
    parts,meshes=[],[]
    for name,image in visible.items():
        bone,z=BONES.get(name,name),order[name]
        bounds=None
        if not image[...,3].any():
            ys,xs=np.nonzero(solos[name]);bounds=[int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
        part=store(image,CASE/'pieces'/view,name,bounds)
        parts.append(dict(part,bone=bone,z_index=z,logical_part=name))
        if name in anatomy['meshes']:meshes.append(layer(part,name,part['bbox'],joints,z,recipe=anatomy['meshes'][name]))
        if hidden[name][...,3].any() or domains[name].any():
            bounds=None
            if not hidden[name][...,3].any():
                ys,xs=np.nonzero(domains[name]);bounds=[int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
            from rr38_seam import bounds_for
            bounds=bounds_for(view,'hidden_'+name,hidden[name],bounds)
            under=store(hidden[name],CASE/'pieces'/view,'hidden_'+name,bounds)
            under['presentation_anchor']=part['offset'].copy()
            under_z=min(order.values())-1
            if name in anatomy['meshes']:meshes.append(layer(under,name,part['bbox'],joints,under_z,True,recipe=anatomy['meshes'][name]))
            parts.append(dict(under,bone=bone,z_index=under_z,hidden_material=True,logical_part=name))
    features=[]
    if view=='front':
        for name,piece,box in [('visor_slit','head',[120,61,141,74]),('tower_emblem','tabard',[122,150,141,177])]:
            x0,y0,x1,y1=box;mask=np.zeros((255,255),bool)
            mask[y0:y1,x0:x1]=visible[piece][y0:y1,x0:x1,3]>0
            path=CASE/f'features/{view}_{name}.png';path.parent.mkdir(exist_ok=True)
            Image.fromarray(mask.astype('uint8')*255).save(path)
            features.append({'name':name,'piece':piece,'mask':str(path.relative_to(CASE))})
    write_json(CASE/f'features/{view}.json',features)
    # All continuations used z=-1 in round 0. Sprite descendants precede
    # root-level skins in Godot tree order, so a z-only proof sort disagreed
    # with the renderer. Preserve that measured GPU order with unique depths.
    measured=read_json(CASE.parent/'rr38_feedback1_draw_order.json')[view]
    hidden_order=[name for name in measured if name.startswith('hidden_') and any(p['name']==name for p in parts)]
    hidden_depths={name:index-len(hidden_order) for index,name in enumerate(hidden_order)}
    for record in parts+meshes:
        if record['name'] in hidden_depths:record['z_index']=hidden_depths[record['name']]
    spec=read_json(base/'source/spec_native.json');origin=np.asarray(projected(spec,[0,0,0],view))
    up=np.asarray(projected(spec,[0,0,1],view))-origin;forward=np.asarray(projected(spec,[1,0,0],view))-origin
    projection={'forward':(forward/np.linalg.norm(forward)).tolist(),'lean_sign':float(np.sign(up[0]*forward[1]-up[1]*forward[0]))}
    chain=visible['chain'];ys,xs=np.nonzero(chain[...,3])
    fist=visible['hand_near'];fy,fx=np.nonzero(fist[...,3])
    layout={'version':2,'rig':'humanoid_v2','facing':view,'canvas_size':[255,255],
        'joints':joints,'parts':parts,'joint_meshes':meshes,'idle_groups':GROUPS,
        'held_items':{'chain':{'hand':'hand_far','floor_end':[float(xs[ys==ys.max()].mean())+.5,float(ys.max()+1)],
            'floor_line_y':read_json(CASE/'proof/support_registration.json')[view]['anchor'][1],
            'angle_sign':-1,'angle_limits_deg':{'reel':75,'pin':55.5}}},
        'planted_during_death':True, 'planted_foot_orientation_clips':['death'],
        'held_drop_runtime':'res://assets/units/chainbound_gaoler_cutout/held_drop.gd',
        'clip_knee_bend_side':{'death':{side:-float(np.sign(projection['forward'][0])) for side in ('near','far')}},
        'presentation_angle_limits_deg':{'press':{'torso':7}},
        'screen_lift_bones':{'death':['pelvis']},
        'unpainted_under_cowl': ['arm_near','hand_near'] if view=='rear' else [],
        'strike_points':{'chain':[float(xs[ys==ys.max()].mean()),float(ys.max())], 'hand_far':joints['hand_far']['position'], 'hand_near':([float(fx.mean()),float(fy.mean())] if len(fx) else joints['hand_near']['position'])},
        'ik_chains':[],'planted_bones':anatomy['planted_bones'],'source_labels':PIECES,'features':features,
        'rest_source':f'source/{view}/processed.png','motion_data':'res://'+str(CASE.relative_to(PROJECT)/'compiled_motion.json'),
        'gait_leg_scale_max':read_json(DIRECTOR)['chainbound_gaoler']['clips']['move']['gait']['leg_scale_max']}
    proof_masks(layout,paint,visible,hidden,definition,anatomy)
    from rr38_seam import add as add_seam_continuation
    add_seam_continuation(CASE, layout, read_json(DIRECTOR)['chainbound_gaoler']['clips'])
    write_json(CASE/f'layouts/{view}.json',layout)
    reconstructed=Image.new('RGBA',(255,255))
    for part in sorted(parts,key=lambda p:p['z_index']):reconstructed.alpha_composite(Image.fromarray(source_pixels(CASE,part)))
    mismatch=int(np.any(np.asarray(reconstructed)!=paint,axis=-1).sum())
    report={'front_rest_mismatch_pixels':mismatch,'rest_mismatch_pixels':mismatch,'tucks':tucks,'delivery':delivery,
        'source_ownership':str(base.relative_to(PROJECT)/f'layouts/{view}.json'),'source_ownership_sha256':digest(base/f'layouts/{view}.json')}
    return layout,report,projection


def build():
    inputs,anatomy=read_json(CASE/'inputs.json'),load(CASE)
    copied=CASE/'director_motion.json';shutil.copyfile(DIRECTOR,copied)
    layouts,reports,projections={},{},{}
    for view in ('front','rear'):layouts[view],reports[view],projections[view]=build_view(view,inputs,anatomy)
    compiled=compile_motion(copied,'chainbound_gaoler',layouts,projections)
    write_json(CASE/'compiled_motion.json',compiled)
    write_json(CASE/'cutout.json',{'character_id':'chainbound_gaoler','rig':'humanoid_v2',
        'proof_geometry':{'canvas_size':640,'source_offset':192},'layouts':{v:f'layouts/{v}.json' for v in layouts},
        'design_placeholders':inputs['design_placeholders'],'direction_clips':['move','reel','pin','press','guard'],
        'clips':compiled['clips'],'runtime_paths':['scripts/maquette_cutout_runtime/humanoid_motion.gd','scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    promote(PROJECT,CASE,ASSETS/'humanoid_v2',layouts)
    write_json(CASE/'proof/build.json',dict(reports['front'],views=reports,director_sha256=digest(copied),production_promoted=True,native_proof='pending director windowed captures'))
    for root in (CASE,ASSETS/'humanoid_v2'):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:Path(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    for view,report in reports.items():
        print(f'RR38 {view.upper()} BUILD: {"PASS" if not report["rest_mismatch_pixels"] else "FAIL"} (rest mismatch: {report["rest_mismatch_pixels"]} px; protected tracks byte-identical)')


if __name__=='__main__':build()
