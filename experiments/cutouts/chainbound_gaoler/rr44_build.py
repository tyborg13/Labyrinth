"""Deterministic source cuts, painted backing, meshes and director motion."""
import shutil
import numpy as np
from PIL import Image
from rr44_case import PROJECT, BASE, CASE, ASSETS, STAGED, JOBS, VIEWS, protected, DEFAULTS
from rr44_partition import cut, backing, TRACES
from rr44_maquette import fit, GRIPS
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.promotion import promote


def build():
    protected()
    # Feedback 2 changes ownership/caps, not the certified front arm pose.
    # Reuse only the hash-bound native delivery, avoiding another fit search.
    status=read_json(CASE/'maquette/fit_status.json')
    from spec.art_identity.maquettes.blender.contract import digest as spec_digest
    if status.get('native_verified') and status['spec_hash']==spec_digest(read_json(CASE/'maquette/spec_native.json')) and status['acceptance_sha256']==digest(CASE/'maquette/delivery/mq15_acceptance.json'):
        joints=read_json(CASE/'maquette/joints_source_px.json')
    else:joints=fit()
    CASE.mkdir(parents=True, exist_ok=True)
    for name in ('anatomy.json','inputs.json','cutout.json','material_contract.json'):
        shutil.copyfile(BASE/name,CASE/name)
    for folder in ('features','holes','seams','tucks','checks','uncovered','ownership'):
        shutil.copytree(BASE/folder,CASE/folder,dirs_exist_ok=True)
    (CASE/'proof').mkdir(exist_ok=True)
    for name in ('support_registration.json',):
        shutil.copyfile(BASE.parent/'rr38/proof'/name,CASE/'proof'/name)
    shutil.copyfile(STAGED/'motion_tracks.json',CASE/'director_motion.json')
    inputs = read_json(CASE/'inputs.json'); anatomy = read_json(CASE/'anatomy.json')
    # The rear far boot meets the coat hem; its trouser is covered above it.
    # Re-owning the boot ink must not demand a hypothetical visible trouser.
    covers=anatomy['tucks']['pieces']['foot_far']['covers']
    if 'coat_far' not in covers:covers.append('coat_far')
    write_json(CASE/'anatomy.json',anatomy)
    report = dict(native_pixels=False, director_sha256=digest(CASE/'director_motion.json'),
                  director_files=protected(), views={}, clamps=[], native_calibration='hash-bound round-0 replay required; current windowed acceptance pending')
    layouts = {}
    for view, (_, job) in VIEWS.items():
        inputs[view+'_job'] = str((JOBS/job).relative_to(PROJECT))
        layout = read_json(BASE/f'layouts/{view}.json')
        decisions = read_json(CASE.parent/'rr44_feedback1.json')
        layout['held_follow_reference_frames'] = {'move': decisions['held_follow_reference_frame']}
        layout['painted_backing_authority']='rr44_feedback2'
        layout['painted_reference_space']=True
        layout['painted_node_transforms']=True
        layout['stable_source_raster']=True
        layout['motion_data'] = 'res://'+str((CASE/'compiled_motion.json').relative_to(PROJECT))
        source = CASE/f'source/{view}'; source.mkdir(parents=True, exist_ok=True)
        for name in ('processed.png','processed.json'): shutil.copyfile(JOBS/job/name,source/name)
        paint = np.asarray(Image.open(source/'processed.png').convert('RGBA'))
        region = np.asarray(Image.open(STAGED/f'{view}_r1_region.png').convert('L'))>0
        visible,contact_receipt = cut(BASE,layout,paint,region,with_receipt=True)
        write_json(CASE/f'ownership/{view}_underlay_contacts.json',contact_receipt)
        previous = {p['name']:source_pixels(BASE,p) for p in layout['parts'] if p.get('hidden_material')}
        underlay = np.asarray(Image.open(STAGED/f'{view}_body_underlay.png').convert('RGBA')).copy()
        underlay[underlay[...,3]==0] = 0
        hidden, footprints, authority, certificates,density_authorities = backing(visible,underlay,previous,layout)
        for image in hidden.values(): image[region & (paint[...,3]==0)] = 0
        # Remove obsolete chain-arm continuations in the old high hold.
        for name in ('hidden_arm_far','hidden_hand_far','hidden_chain'):
            hidden[name][:] = 0
        for bone, semantic in [('upper_far','shoulder_far'),('fore_far','elbow_far'),('hand_far','hand_far')]:
            layout['joints'][bone]['position'] = joints[view][semantic]
        layout['joints']['chain']['position'] = GRIPS[view]
        chain = visible['chain']; ys,xs = np.nonzero(chain[...,3])
        painted_end = [float(xs[ys==ys.max()].mean())+.5,float(ys.max()+1)]
        from rr44_feedback2_repairs import source_layout
        # The director explicitly kept r1's death. Its floor_end is the
        # animation's landing/rotation datum, not a request to re-fit the
        # pivot whenever ownership removes a painted boot fragment.
        death_datum=source_layout(view)['held_items']['chain']['floor_end']
        layout['held_items']['chain'].update(source_grip=GRIPS[view],floor_end=death_datum,
            floor_end_provenance='director-approved r1 death datum; retained across ownership-only cleanup',painted_end_source=painted_end,
            release_provenance='rigid_source_rgba',component_provenance='rigid_source_rgba',presentation_grip_part='hand_far',cap_release_parent='hand_far')
        layout['strike_points'].update(chain=[painted_end[0],painted_end[1]-1],hand_far=GRIPS[view])
        if view=='front':
            z = {p['name']:p['z_index'] for p in layout['parts']}
            for p in layout['parts']:
                if p['name']=='arm_far': p['z_index']=z['coat_far']+1
                if p['name']=='hand_far': p['z_index']=z['torso']-1
        images = {**visible,**hidden}; meshes = []
        from rr44_feedback2_repairs import backing as repair_backing,caps as boundary_caps,retired_backing_texels
        repair_backing(images,view)
        layout['retired_backing_texels']=retired_backing_texels(view)
        new_caps=boundary_caps(CASE,view,images,layout,anatomy)
        # Caps fill holes behind ALL existing backing. Interleaving them
        # with other garments cuts accepted textured regions into flat
        # fragments even when each cap is below its own original backing.
        hidden_floor=min(2*p['z_index'] for p in layout['parts'] if p.get('hidden_material') and not p.get('joint_cap_layer'))
        for part in layout['parts']:
            if part.get('hidden_material'):
                part['z_index']=2*part['z_index']+(hidden_floor-1+int(part.get('joint_cap_fore',False)) if part.get('joint_cap_layer') else 0)
        from humanoid_cutout.painted_caps import prepare as cap_band,apply as cap_mesh
        near_cap=cap_band(CASE,view,images,layout,anatomy)
        far_cap=new_caps['joint_cap_arm_far_fore'][0]
        from humanoid_cutout.painted_caps import band
        near_visible_cap=dict(near_cap,include_outline=True,texels=np.argwhere(band(images['arm_near'],layout['joints'],
            anatomy['meshes']['arm_near'],near_cap['depth_px'],__import__('maquette_motion.material_palette',fromlist=['rules']).rules(CASE,view),True))[:,::-1].tolist())
        far_visible_cap=dict(far_cap,include_outline=True,texels=np.argwhere(band(images['arm_far'],layout['joints'],
            anatomy['meshes']['arm_far'],far_cap['depth_px'],__import__('maquette_motion.material_palette',fromlist=['rules']).rules(CASE,view),True))[:,::-1].tolist())
        cap_rows={name:list(rows) for name,rows in new_caps.items()}
        for name,row in [('hidden_arm_near',near_cap),('arm_near',near_visible_cap),('arm_far',far_visible_cap)]:
            cap_rows.setdefault(name,[]).append(row)
        # A joint band is its own source paint, not an underlay certificate.
        for name,rows in cap_rows.items():
            if name in certificates:
                for row in rows:
                    for x,y in row['texels']:certificates[name][y,x]=False
        from rr38_build import store, proof_masks
        from maquette_motion.material_palette import rules
        for p in layout['parts']:
            name = p['name']; image = images[name]
            # Source-space rebuilds need no procedural expansion or donor.
            from rr44_feedback2_repairs import bounds as registered_bounds
            empty = registered_bounds(view,name,image,logical=p['logical_part'])
            part = store(image,CASE/'pieces'/view,name,empty,case=CASE)
            p.update(part); p.pop('presentation_anchor',None)
            logical = p['logical_part']
            if logical in anatomy['meshes']:
                # Ownership can expand an image crop by a fringe texel; it
                # must not retune the existing garment's deformation field.
                from rr44_feedback2_repairs import weight_bounds
                bounds = weight_bounds(view,logical)
                mesh=layer(p,logical,bounds,layout['joints'],p['z_index'],bool(p.get('hidden_material')),recipe=anatomy['meshes'][logical])
                # Preserve the approved far sleeve's skinned contour. Its
                # rigid fore/upper caps are hidden fills, not a replacement
                # deformation field for the visible sleeve.
                elbow_caps={'hidden_arm_near':near_cap,'arm_near':near_visible_cap}
                definitions=([elbow_caps[name]] if name in elbow_caps and elbow_caps[name]['texels'] else [])+new_caps.get(name,[])
                if definitions:mesh=cap_mesh(mesh,definitions)
                if any(row['bone'] not in anatomy['meshes'][logical]['bones'] for row in new_caps.get(name,[])):
                    mesh['rigid_source_alignment']=True
                meshes.append(mesh)
            elif new_caps.get(name):
                from humanoid_cutout.painted_caps import rigid_base
                mesh=cap_mesh(rigid_base(p),new_caps[name]);mesh['rigid_source_alignment']=True;meshes.append(mesh)
            before=next((q for q in read_json(BASE/f'layouts/{view}.json')['parts'] if q['name']==name),None)
            original = source_pixels(BASE,before) if before else np.zeros_like(image)
            changed = np.any(image!=original,axis=-1)
            for cap in new_caps.get(name,[]):
                for x,y in cap['texels']:changed[y,x]=True
            # Keep a copied band and its source in one density paint partition.
            for rows in new_caps.values():
                for cap in rows:
                    if cap['source']==name:
                        for x,y in cap['texels']:changed[y,x]=True
            if p.get('joint_cap_layer'):changed[:]=True
            if name in ('arm_near','hidden_arm_near','arm_far','hidden_arm_far'):
                # The new joint ownership needs one paint partition on both
                # layers, even where their raw RGBA already matched. Retaining
                # previously treated visible paint would give the copied cap
                # a different colour from its own sleeve after adoption.
                cap=({'arm_near':near_visible_cap,'hidden_arm_near':near_cap,'arm_far':far_visible_cap,'hidden_arm_far':far_cap})[name]
                for x,y in cap['texels']:changed[y,x]=True
            if p.get('hidden_material') and not p.get('joint_cap_layer') and logical in density_authorities: changed |= density_authorities[logical]
            Image.fromarray((changed*255).astype(np.uint8)).save(CASE/f'ownership/rr44_{view}_{name}.png')
        layout['joint_meshes'] = meshes
        from rr44_recipes import rebuild as rebuild_recipes
        rebuild_recipes(CASE,layout,images,authority)
        for name,mask in footprints.items():
            Image.fromarray((mask*255).astype(np.uint8)).save(CASE/f'uncovered/{view}_{name}_footprint.png')
        for name,mask in certificates.items():
            Image.fromarray((mask*255).astype(np.uint8)).save(CASE/f'uncovered/{view}_{name}_painted.png')
        Image.fromarray((authority*255).astype(np.uint8)).save(CASE/f'uncovered/{view}_paint_authority.png')
        write_json(CASE/f'ownership/{view}_rr44.json',dict(traces=TRACES[view],rule='copy approved registered RGBA exactly'))
        rest = Image.new('RGBA',(255,255))
        for p in sorted(layout['parts'],key=lambda p:p['z_index']): rest.alpha_composite(Image.fromarray(images[p['name']]))
        mismatch = int(np.any(np.asarray(rest)!=paint,axis=-1).sum())
        # Underlay must never leak in the neutral source assembly.
        report['views'][view] = dict(rest_mismatch_pixels=mismatch, footprint_pixels={n:int(m.sum()) for n,m in footprints.items()},
                                    painted_pixels={n:int(m.sum()) for n,m in certificates.items()})
        from humanoid_cutout.tucks import required_tuck
        tucks = []
        for name,policy in anatomy['tucks']['pieces'].items():
            if not visible[name][...,3].any(): continue
            required = required_tuck(name,visible,layout['joints'],anatomy['tucks'],continuation=hidden['hidden_'+name][...,3]>0)
            supplied = (visible[name][...,3]>0) | (hidden['hidden_'+name][...,3]>0)
            bindings = []
            for receiver,mask in certificates.items():
                owned = required & ~supplied & mask
                if owned.any():
                    bindings.append(dict(part=receiver,texels=np.argwhere(owned)[:,::-1].tolist()))
                    supplied |= owned
            # As in rr-42, a director-cleared procedural tuck retains the
            # exact visible source owner at that coordinate. It cannot demand
            # new sleeve/leg paint where the supplied underlay is clear.
            clear=required & ~supplied
            for receiver in sorted(visible,key=lambda n:next(p['z_index'] for p in layout['parts'] if p['name']==n),reverse=True):
                owned=clear & ~supplied & (visible[receiver][...,3]>0)
                if owned.any():
                    bindings.append(dict(part=receiver,texels=np.argwhere(owned)[:,::-1].tolist()))
                    supplied |= owned
            mask_path = CASE/f'tucks/{view}_{name}.png'; Image.fromarray((required*255).astype(np.uint8)).save(mask_path)
            tucks.append(dict(piece=name,minimum_px=policy['depth_px'],cover=policy['covers'],required_mask=str(mask_path.relative_to(CASE)),
                              required_pixels=int(required.sum()),missing_pixels=int((required & ~supplied).sum()),owner_bindings=bindings))
            # Demand comes from the rest ownership/underlay and tuck recipe,
            # independently of whether the receiving texture supplies it.
            path=CASE/f'uncovered/{view}_{name}.png'
            domain=np.asarray(Image.open(path).convert('L'))>0
            domain[authority]=False
            if name in ('arm_far','hand_far','chain'): domain[:]=False
            domain |= required & ~(authority & (underlay[...,3]==0))
            domain |= certificates.get('hidden_'+name,np.zeros((255,255),bool))
            Image.fromarray((domain*255).astype(np.uint8)).save(path)
        report['views'][view].update(tucks=tucks,front_rest_mismatch_pixels=mismatch)
        proof_masks(layout,paint,visible,{n.removeprefix('hidden_'):im for n,im in hidden.items()},rules(CASE,view),anatomy,case=CASE)
        from rr44_surface_policy import checks as paint_checks
        paint_checks(CASE,layout)
        # Palette diagnostics also recognize exact registered director paint.
        # The separate painted-exposure gate verifies its coordinate and RGBA.
        for name,mask in certificates.items():
            path=CASE/f'uncovered/donor_{view}_{name}.png'
            legal=np.asarray(Image.open(path).convert('L'))>0
            Image.fromarray(((legal|mask)*255).astype(np.uint8)).save(path)
        from rr42_references import rebuild
        rebuild(CASE,layout,images,anatomy,rest)
        write_json(CASE/f'layouts/{view}.json',layout); layouts[view] = layout
    write_json(CASE/'inputs.json',inputs)
    from rr44_maquette_annotations import prepare as maquette_annotations
    maquette_annotations()
    write_json(CASE/'chosen_defaults.json',DEFAULTS)
    projection = read_json(BASE/'compiled_motion.json')['projection']
    compiled = compile_motion(CASE/'director_motion.json','chainbound_gaoler',layouts,projection)
    from rr44_motion import apply
    compiled, report['clamps'] = apply(compiled)
    for view,layout in layouts.items():
        layout['held_items']['chain']['presentation_release_at']={clip:compiled.get('view_release_at',{}).get(view,{}).get(clip,definition.get('release_at',{})).get('chain',float('inf'))
            for clip,definition in compiled['clips'].items() if 'chain' in compiled.get('view_release_at',{}).get(view,{}).get(clip,definition.get('release_at',{}))}
        write_json(CASE/f'layouts/{view}.json',layout)
    write_json(CASE/'compiled_motion.json',compiled)
    definition = read_json(CASE/'cutout.json'); definition['clips']=compiled['clips']
    # Move now uses FK pendulums, not signed hand targets. Its independent
    # per-frame pendulum and walk gates own that directional proof.
    definition['direction_clips'] = [c for c in definition['direction_clips'] if c!='move']
    definition['design_placeholders'] = compiled['TODO_DESIGN']
    inputs['design_placeholders'] = compiled['TODO_DESIGN']
    write_json(CASE/'inputs.json',inputs)
    write_json(CASE/'cutout.json',definition)
    report.update(tucks=report['views']['front']['tucks'],front_rest_mismatch_pixels=report['views']['front']['rest_mismatch_pixels'])
    from rr44_calibration import certificate
    report.update(native_calibration=certificate(),maquette_native=read_json(CASE/'maquette/fit_status.json'))
    write_json(CASE/'proof/build.json',report)
    promote(PROJECT,CASE,ASSETS/'humanoid_v2',layouts)
    for root in (CASE,ASSETS/'humanoid_v2'):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts: type(path)(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    for view,row in report['views'].items(): print(f'RR44 {view.upper()} SOURCE REST: {row["rest_mismatch_pixels"]} px mismatch')
    if any(r['rest_mismatch_pixels'] for r in report['views'].values()): raise ValueError('Source rest differs; inspect underlay/ownership overlaps')


if __name__ == '__main__': build()
