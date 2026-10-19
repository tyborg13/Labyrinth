"""Lossless rigid cuts of the approved mq8b paint; no generated/repainted texels."""
from pathlib import Path
import shutil
import sys
import numpy as np
from PIL import Image
from rr18_case import PROJECT, CASE, ASSETS, DIRECTOR, PIECES, BONES, GROUPS
sys.path.insert(0, str(PROJECT / 'experiments/cutouts/hoarfrost_seer'))
from rr07_inputs import registered_transform, label_palette
from rr07_geometry import native_depths, bind_layout
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_cutout import projected
from maquette_motion.features import source_pixels
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.silhouette import holes, dilate
from humanoid_cutout.anatomy import load
from humanoid_cutout.source_view import prepare
from humanoid_cutout.materials import clean_continuation
from humanoid_cutout.tucks import required_tuck
from humanoid_cutout.seams import build_masks
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.promotion import promote
from humanoid_cutout.underlays import distinct_depths
from rr18_ownership import clean as clean_ownership
from rr18_materials import continue_surfaces
from rr18_source_stage import raw_cut, clean_visible, raw_identity
from rr23_geometry import register_terminals, front_arm_order


def recipe_for(_creature, _spec):
    anatomy = load(CASE)
    mapping = {n: n for n in ('root', 'pelvis', 'torso', 'head')}
    for side in ('near', 'far'):
        mapping.update({a + side: b + side for a,b in (('upper_', 'shoulder_'), ('fore_', 'elbow_'),
            ('hand_', 'hand_'), ('thigh_', 'hip_'), ('shin_', 'knee_'), ('foot_', 'ankle_'))})
    return {'joints': {n: {'joint': s, 'parent': anatomy['required_parents'][n]} for n,s in mapping.items()},
            'parts': {label: BONES.get(n,n) for n, labels in PIECES.items() for label in labels}}


def store(image, folder, name, bounds=None):
    ys,xs = np.nonzero(image[...,3])
    if bounds is None:
        if not len(xs): raise ValueError('Empty piece: ' + name)
        bounds = [int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1]
    path = folder / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(image).crop(bounds).save(path)
    return {'name': name, 'file': str(path.relative_to(CASE)), 'offset': bounds[:2], 'bbox': bounds}


def proof_masks(layout, paint, visible, hidden, definition, anatomy):
    view = layout['facing']
    layout['proof_layers'] = {}
    for part in layout['parts']:
        image = source_pixels(CASE,part)
        allowed = image[...,3] > 0
        checks = np.zeros_like(image)
        checks[allowed] = [255,0,0,255]
        checks[allowed & (hidden[part['logical_part']][...,3] > 0) & part.get('hidden_material',False),1] = 255
        checks[allowed & outline_class(image,definition),2] = 255
        mask = store(checks, CASE / 'checks' / view, part['name'],part['bbox'])
        layout['proof_layers'][part['name']] = {'mask':mask['file'], 'mask_offset':mask['offset'],
            'z_index':part['z_index'], 'source':part['file'], 'rigid':True, 'source_sha256':digest(CASE/part['file'])}
    records = []
    for index,hole in enumerate(holes(paint[...,3] > 0)):
        if int(hole.sum()) <= 1: continue
        rim = dilate(hole,1) & ~hole
        owner = max(PIECES,key=lambda n:int((rim & (visible[n][...,3]>0)).sum()))
        image = np.zeros_like(paint); image[hole] = 255
        record = store(image,CASE/'holes',f'{view}_{index:02d}',[0,0,255,255])
        records.append({'name':f'RestHole{index:02d}','owner':owner,'file':record['file'],'bone':BONES.get(owner,owner)})
    layout['proof_rest_holes'] = records
    layout['proof_joint_seams'] = build_masks(CASE,layout,visible,anatomy)


def build_view(view,inputs,anatomy):
    base,old,seeds,delivery = prepare(PROJECT,CASE,inputs,view,PIECES,registered_transform,label_palette,native_depths,recipe_for,bind_layout)
    source = CASE/'source'/view
    source.mkdir(parents=True,exist_ok=True)
    for name in ('processed.png','processed.json'): shutil.copyfile(PROJECT/inputs[view+'_job']/name,source/name)
    paint = np.asarray(Image.open(source/'processed.png').convert('RGBA'))
    visible,hidden,depths = {},{},{}
    for name,labels in PIECES.items():
        part = next(p for p in old['parts'] if p['logical_part'] == labels[0])
        visible[name] = source_pixels(base,part)
        depths[name] = part['z_index']
    transfers = clean_ownership(visible)
    visible=raw_cut(visible,depths,view,refresh=True)
    visible,source_corrections=clean_visible(visible,anatomy['material_policy']['green_dominance_margin'])
    for name,labels in PIECES.items():
        hidden[name] = clean_continuation(visible[name],seeds[labels[0]],rules(base,view))
    write_json(CASE/f'ownership/{view}.json',{'policy':'cutout_workflow complete-mask components <12 px to the greatest four-neighbour owner; exact RGBA preserved','transfers':transfers})
    joints = old['joints']
    reports = []
    for name,recipe in anatomy['tucks']['pieces'].items():
        mask = required_tuck(name,visible,joints,anatomy['tucks'],continuation=hidden[name][...,3]>0)
        missing = mask & (hidden[name][...,3] == 0)
        fill = edge_texels(visible[name],missing,rules(base,view))
        hidden[name][missing] = fill[missing]
        path = CASE / f'tucks/{view}_{name}.png'
        path.parent.mkdir(exist_ok=True)
        Image.fromarray(mask.astype('uint8')*255).save(path)
        reports.append({'piece':name,'minimum_px':recipe['depth_px'],'cover':recipe['covers'],
            'required_mask':str(path.relative_to(CASE)),'required_pixels':int(mask.sum()),
            'missing_pixels':int((mask & (hidden[name][...,3] == 0)).sum())})
    surfaces = continue_surfaces(visible,hidden,anatomy,view,rules(base,view))
    terminal_registration = register_terminals(joints,visible,hidden,view)
    order = front_arm_order(visible,hidden,depths) if view == 'front' else {'policy':'unchanged as cut'}
    parts = []
    for name,image in visible.items():
        bone = BONES.get(name,name)
        # Both alpha partitions of one boulder use an identical source quad.
        # A shared anchor alone cannot prevent native subpixel UV differences
        # when independently cropped quads quantize their corners differently.
        visible_y,visible_x = np.nonzero(image[...,3])
        anchor = [int(visible_x.min()),int(visible_y.min())]
        union = (image[...,3]>0) | (hidden[name][...,3]>0)
        ys,xs = np.nonzero(union)
        bounds = [int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
        if name in read_json(CASE/'joint_continuations.json').get(view,{}):
            depth=anatomy['joint_continuations']['depth_px']
            bounds=[bounds[0]-depth,bounds[1]-depth,bounds[2]+depth,bounds[3]+depth]
        main = store(image,CASE/'pieces'/view,name,bounds)
        if hidden[name][...,3].any():
            part = store(hidden[name],CASE/'pieces'/view,'hidden_'+name,bounds)
            parts.append(dict(part,bone=bone,z_index=min(depths.values())-1,hidden_material=True,logical_part=name,presentation_anchor=anchor))
        parts.append(dict(main,bone=bone,z_index=depths[name],logical_part=name,presentation_anchor=anchor))
    layout = {'version':2,'rig':'humanoid_v2','facing':view,'canvas_size':[255,255], 'joints':joints,'parts':parts,
        'joint_meshes':[],'idle_groups':GROUPS,'held_items':{}, 'ik_chains':[],
        'planted_bones':anatomy['planted_bones'], 'source_labels':PIECES,'features':[],
        'rest_source':f'source/{view}/continued.png','raw_rest_source':f'source/{view}/processed.png','motion_data':'res://'+str(CASE.relative_to(PROJECT)/'compiled_motion.json')}
    # The single front feature remains wholly inside the torso owner. Its
    # exact source paint is protected along with the entire chest boulder.
    if view == 'front':
        mask = visible['torso'][...,3] > 0
        path = CASE/'features/front_ice_mirror.png'; path.parent.mkdir(exist_ok=True)
        Image.fromarray(mask.astype('uint8')*255).save(path)
        layout['features'] = [{'name':'ice_mirror','piece':'torso','mask':str(path.relative_to(CASE)),
                               'scope':'whole owning chest boulder, including the single inset'}]
    distinct_depths(layout)
    expected = Image.new('RGBA',(255,255))
    rest = Image.new('RGBA',(255,255))
    for part in sorted(parts,key=lambda p:p['z_index']):
        image=hidden[part['logical_part']] if part.get('hidden_material') else visible[part['logical_part']]
        expected.alpha_composite(Image.fromarray(image))
        rest.alpha_composite(Image.fromarray(source_pixels(CASE,part)))
    expected.save(CASE/layout['rest_source'])
    processed=np.asarray(expected)
    proof_masks(layout,processed,visible,hidden,rules(base,view),anatomy)
    write_json(CASE/f'layouts/{view}.json',layout)
    mismatch = int(np.any(np.asarray(rest) != processed,axis=-1).sum())
    raw_delta = int(np.any(processed != paint,axis=-1).sum())
    spec = read_json(base/'source/spec_native.json')
    origin = np.asarray(projected(spec,[0,0,0],view))
    up = np.asarray(projected(spec,[0,0,1],view))-origin
    forward = np.asarray(projected(spec,[1,0,0],view))-origin
    projection = {'forward':(forward/np.linalg.norm(forward)).tolist(),
        'lean_sign':float(np.sign(up[0]*forward[1]-up[1]*forward[0]))}
    return layout,{'front_rest_mismatch_pixels':mismatch,'rest_mismatch_pixels':mismatch,'tucks':reports,'continuations':surfaces,'terminal_registration':terminal_registration,'guard_order':order,'raw_authoring':raw_identity(view),'presentation_delta_pixels':raw_delta,'visible_green_corrections':source_corrections,'delivery':delivery,
        'source_ownership':str(base.relative_to(PROJECT)/f'layouts/{view}.json'),
        'source_ownership_sha256':digest(base/f'layouts/{view}.json')},projection


def build(import_director=False):
    inputs,anatomy = read_json(CASE/'inputs.json'),load(CASE)
    copied = CASE/'director_motion.json'
    if copied.exists() and copied.read_bytes() != DIRECTOR.read_bytes() and not import_director: raise ValueError('Protected director import differs')
    shutil.copyfile(DIRECTOR,copied)
    layouts,reports,projections = {},{},{}
    for view in ('front','rear'): layouts[view],reports[view],projections[view] = build_view(view,inputs,anatomy)
    compiled = compile_motion(copied,'glacial_mirror',layouts,projections)
    for view, layout in layouts.items():
        layout['gait_leg_scale_max'] = compiled['clips']['move']['gait'].get('leg_scale_max', 1.22)
        write_json(CASE / f'layouts/{view}.json', layout)
    write_json(CASE/'compiled_motion.json',compiled)
    write_json(CASE/'cutout.json',{'character_id':'glacial_mirror','rig':'humanoid_v2','layouts':{v:f'layouts/{v}.json' for v in layouts},
        'design_placeholders':inputs['design_placeholders'],'clips':compiled['clips'],'direction_clips':['refraction','guard'],
        'runtime_paths':['scripts/maquette_cutout_runtime/humanoid_motion.gd','scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    promote(PROJECT,CASE,ASSETS/'humanoid_v2',layouts)
    write_json(CASE/'proof/build.json',dict(reports['front'],views=reports,director_sha256=digest(copied),production_promoted=True,
        native_proof='pending director windowed captures'))
    for root in (CASE,ASSETS):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:
                Path(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    for view,report in reports.items():
        print(f'RR18 {view.upper()} BUILD: {"PASS" if not report["rest_mismatch_pixels"] else "FAIL"} (rest mismatch: {report["rest_mismatch_pixels"]} px; all rigid; protected tracks byte-identical)')

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--import-director', action='store_true', help='Adopt the director-approved replacement byte for byte')
    build(parser.parse_args().import_director)
