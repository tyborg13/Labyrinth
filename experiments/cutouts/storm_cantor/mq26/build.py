"""Cut approved Cantor paint and register its v2 rig. Never creates paint."""
from pathlib import Path
import json
import shutil
import sys
import numpy as np
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[4]
sys.path[:0] = [str(ROOT/'tools'), str(ROOT)]
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.promotion import promote
from humanoid_cutout.seams import build_masks
from maquette_motion.features import source_pixels
from motion_limits import clamp_limits
CASE = Path(__file__).parent
ASSETS = ROOT/'assets/units/storm_cantor_cutout'
STAGED = ROOT/'spec/peer_benchmark/staged/rr-56'
DIRECTOR = STAGED/'motion_tracks.json'
VIEWS = ('front', 'rear')
PARENTS = {'root':None, 'pelvis':'root', 'torso':'pelvis', 'head':'torso', 'staff':'hand_far', 'bell':'torso',
           'tabard_mid':'pelvis', 'tabard_tip':'tabard_mid', 'cloak_root':'torso', 'cloak_mid':'cloak_root', 'cloak_tip':'cloak_mid','cloth_anchor_near':'cloak_root','cloth_anchor_far':'cloak_root'}
MESHES = {n:{'kind':'chain', 'bones':[parent, n+'_mid', n+'_tip']} for n,parent in [('tabard','pelvis'),('cloak','cloak_root')]}
BONES = {'tabard':'pelvis', 'cloak':'cloak_root', 'torso_back':'torso', 'torso_ribs':'torso'}
for side in ('near','far'):
    PARENTS.update({f'upper_{side}':'torso', f'fore_{side}':f'upper_{side}', f'hand_{side}':f'fore_{side}',
                    f'thigh_{side}':'pelvis', f'shin_{side}':f'thigh_{side}', f'foot_{side}':f'shin_{side}'})
    for name,chain in [('arm',['upper','fore','hand']), ('leg',['thigh','shin','foot'])]:
        names = [n+'_'+side for n in chain]
        MESHES[name+'_'+side] = {'kind':'two_segment','joints':names,'bones':names[:2], 'cuff_rows_px':4,'blend_half_width_px':4}
        BONES[name+'_'+side] = names[0]
GROUPS = {'upper_body':['torso','torso_back','torso_ribs','head','arm_near','hand_near'],
          'weapon_arm':['arm_far','hand_far'],
          'lower_body':['pelvis','tabard','cloak','leg_near','leg_far','foot_near','foot_far']}
CHOSEN_DEFAULTS = {'proof_canvas_size':640, 'proof_source_offset':192, 'diagnostic_mask_rgba':[255,0,0,255],
                   'cpu_triangle_batch_size':128, 'diagnostic_crop_zoom':4}

def polygon(points):
    mask = Image.new('1',(255,255)); ImageDraw.Draw(mask).polygon([tuple(p) for p in points],fill=1)
    return np.asarray(mask)

def store(image, view, name):
    y,x = np.nonzero(image[...,3]); bounds = [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else [0,0,1,1]
    path = CASE/f'pieces/{view}/{name}.png'; path.parent.mkdir(parents=True,exist_ok=True)
    Image.fromarray(image).crop(bounds).save(path)
    return dict(name=name, file=str(path.relative_to(CASE)), offset=bounds[:2], bbox=bounds)

def partition(view):
    reg = read_json(CASE/f'registration/{view}.json')
    paint = np.asarray(Image.open(ROOT/reg['painting']).convert('RGBA'))
    remaining = paint[...,3]>0; images={}; labels=np.zeros(remaining.shape,np.uint8)
    for index,(name,points) in enumerate(reg['ownership_polygons'].items(),1):
        own = polygon(points)&remaining
        im=np.zeros_like(paint);im[own]=paint[own];images[name]=im;labels[own]=index;remaining[own]=False
    if remaining.any(): raise ValueError(f'{view}: {remaining.sum()} unassigned pixels')
    # Exact source-coordinate corrections are an editable ownership record.
    # They never recolour, extend, or re-register any painted texel.
    for name,points in reg.get('ownership_exact_pixels',{}).items():
        for x,y in points:
            for image in images.values():image[y,x]=0
            images[name][y,x]=paint[y,x];labels[y,x]=list(images).index(name)+1
    if view=='front':
        # Ribs retain their exact painted pixels in front of the independent bell.
        images['torso_ribs']=np.zeros_like(paint)
        for points in reg['rib_polygons']:
            own=polygon(points)&(images['torso_back'][...,3]>0)
            images['torso_ribs'][own]=images['torso_back'][own];images['torso_back'][own]=0
    return reg,paint,images,labels

def anatomy(layouts):
    # The director separately keys the rigid staff tilt and bell sway. Their
    # individual paint/attachment gates cover them; the three bob groups prove
    # the body's exact translations without treating approved sway as a defect.
    upper=['torso','head','upper_near','fore_near','hand_near']
    weapon=['upper_far','fore_far','hand_far']
    joins=[['head','torso'],['torso','pelvis'],['tabard','pelvis'],['cloak','torso'],['staff','hand_far']]
    legs={s:{} for s in ('near','far')};knees={'near_straight_deg':6,'by_view':{}}
    for view,layout in layouts.items():
        knees['by_view'][view]={}
        for side in legs:
            a,b,c=[np.asarray(layout['joints'][n+'_'+side]['position']) for n in ('thigh','shin','foot')]
            u=b-a;v=c-b;ray=c-a;cross=ray[0]*u[1]-ray[1]*u[0];bend=abs(float(np.degrees(np.arctan2(u[0]*v[1]-u[1]*v[0],u@v))))
            legs[side][view]={'bend_side':(1 if view=='front' else -1) if bend<=6 else int(np.sign(cross))}
            knees['by_view'][view][side]={'near_straight_deg':6,'crouched_stance_deg':bend}
    for side in legs: joins += [[f'arm_{side}','torso'],[f'hand_{side}',f'arm_{side}'],[f'leg_{side}','pelvis'],[f'foot_{side}',f'leg_{side}']]
    return {'schema_version':1,'required_parents':PARENTS,'forbidden_joints':['belt','pauldron_near','pauldron_far','cowl','buckle'],
            'meshes':MESHES,'idle_groups':{'upper_body':{'bones':upper,'stationary':False},'weapon_arm':{'bones':weapon,'stationary':False},
            'lower_body':{'bones':[n for n in PARENTS if n not in upper+weapon+['staff','bell']],'stationary':True}},
            'knee_policy':knees,'legs':legs,'planted_bones':['foot_near','foot_far'],'planted_tolerance_px':0.5,'held_depth_roles':{},
            'ownership':{'names':list(layouts['front']['source_labels']),'segments':{},'joint_pairs':joins,'free_space_owners':[]},
            'joint_continuations':{'depth_px':3,'bounded_pieces':[]},'tucks':{'base_px':3,'pieces':{}},'seam_joins':joins,
            'covered_surfaces':{},'intentionally_empty':{},'held_item_release_exemptions':[{'item':'staff','clip':'death'}],
            'integration':{'production_root':'assets/units/storm_cantor_cutout','rig_directory':'humanoid_v2',
            'production_files':['rig.gd','renderer.gd','held_drop.gd','held_contract.gd','strand_contract.gd','action_adapter.gd'],
            'binding_files':['rig.gd','renderer.gd','held_drop.gd','held_contract.gd','strand_contract.gd','action_adapter.gd','integration.json'],
            'binding_folders':['tools/humanoid_cutout','scripts/maquette_cutout_runtime','experiments/cutouts/storm_cantor/mq26'],
            'scale':{'file':'data/enemies.json','key':'storm_cantor','field':'art_scale','default':1.0},
            'identity_registry':'spec/art_identity/registry.json','identity_id':'storm_cantor','density_id':'storm_cantor_cutout',
            'owner_approval':'cantor-paint-3; director approved take-three; native rig proof pending',
            'identity_kind':'creature','identity_entry_kind':'legacy','identity_boss':True}}

def underlays(view, reg, images):
    """Partition the WHOLE director underlay among its semantic receivers."""
    under=np.asarray(Image.open(STAGED/f'{view}_body_underlay.png').convert('RGBA'))
    assert under.shape==(255,255,4)
    remaining=np.ones((255,255),bool);result={}
    for name in ('head','foot_near','foot_far','leg_near','leg_far','tabard','pelvis','torso','cloak'):
        domain=polygon(reg.get('underlay_footprints',{}).get(name,reg['ownership_polygons'][name]))&remaining
        # Front rib cage back receives all interior hidden fill below the bell.
        if name=='torso' and view=='front':domain|=polygon([[106,98],[139,98],[141,128],[107,128]])&remaining
        remaining[domain]=False
        image=np.zeros_like(under);image[domain]=under[domain]
        if image[...,3].any():result['hidden_'+name]=image
    for name,points in reg.get('ownership_exact_pixels',{}).items():
        if name not in ('head','torso','pelvis','leg_near','leg_far','foot_near','foot_far','tabard','cloak'):continue
        key='hidden_'+name
        if key not in result:result[key]=np.zeros_like(under)
        for x,y in points:
            for image in result.values():image[y,x]=0
            result[key][y,x]=under[y,x]
    # Binding-spec continuations at actual anatomical joins. Use only the
    # director's complete RGBA, including beyond the original silhouette.
    # These receiver overlaps are source registrations, never frame patches.
    from maquette_motion.silhouette import dilate
    joint_pairs=[('head','torso'),('torso','pelvis'),('leg_near','foot_near'),('leg_far','foot_far')]
    original={n:im.copy() for n,im in result.items()}
    for first,second in joint_pairs:
        a,b='hidden_'+first,'hidden_'+second
        if a not in result or b not in result:continue
        am,bm=original[a][...,3]>0,original[b][...,3]>0
        seam=(am&dilate(bm,1))|(bm&dilate(am,1))
        band=dilate(seam,3)
        for receiver,opposite in ((a,bm),(b,am)):
            take=band&opposite&(under[...,3]>0)
            result[receiver][take]=under[take]
    if np.any(remaining & (under[...,3]>0)):raise ValueError('Unowned director underlay')
    assembled=np.zeros_like(under)
    for im in result.values():assembled[im[...,3]>0]=im[im[...,3]>0]
    assert np.array_equal(assembled[under[...,3]>0],under[under[...,3]>0])
    return result

def build():
    layouts={};reports={};projections={}
    for view in VIEWS:
        reg,paint,images,labels=partition(view)
        source=CASE/f'source/{view}';source.mkdir(parents=True,exist_ok=True)
        for n in ('processed.png','processed.json'):shutil.copyfile((ROOT/reg['painting']).parent/n,source/n)
        shutil.copyfile(ROOT/reg['painting'],source/'approved.png')
        shutil.copyfile(STAGED/f'{view}_body_underlay.png',source/'body_underlay.png')
        registered=dict(reg['joints'], cloak_root=reg['joints']['torso'])
        strand_specs=reg.get('rigid_cloth_strands',[])
        for name in ('cloth_anchor_near','cloth_anchor_far'):
            registered[name]=next((row['anchor'] for row in strand_specs if row['bone']==name),reg['joints']['cloak_tip'])
        joints={n:{'parent':PARENTS[n],'position':p} for n,p in registered.items()}
        reconstructed=np.zeros_like(paint)
        for im in images.values():reconstructed[im[...,3]>0]=im[im[...,3]>0]
        mismatch=int(np.any(reconstructed!=paint,axis=-1).sum())
        order=['cloak',*[row['name'] for row in strand_specs],'leg_far','foot_far','leg_near','foot_near','pelvis','tabard','arm_far','staff','hand_far','arm_near','hand_near']
        order+=['torso_back','bell','torso_ribs','torso','head'] if view=='front' else ['torso','head']
        hidden=underlays(view,reg,images)
        strand_bones={}
        for row in strand_specs:
            name=row['name'];strand_bones[name]=row['bone'];mask=polygon(row['polygon'])
            for collection,donor,target in ((images,'cloak',name),(hidden,'hidden_cloak','hidden_'+name)):
                piece=collection[donor].copy();piece[~mask]=0;collection[donor][mask]=0;collection[target]=piece
                # Preserve the approved three-pixel neck on both sides of the
                # attachment, so a rigid strand never uncovers a cut edge.
                top=min(p[1] for p in row['polygon']);yy=np.indices(mask.shape)[0]
                neck=mask&(yy>=top)&(yy<top+row['neck_tuck_px'])
                collection[donor][neck]=piece[neck]
        from staff_reconstruction import apply as reconstruct_staff
        images['staff'],shaft_report=reconstruct_staff(view,paint,images['staff'],images['hand_far'],CASE/'proof')
        write_json(CASE/f'proof/{view}_shaft_reconstruction.json',shaft_report)
        parts=[];meshes=[];checks={}
        for name in list(hidden)+order:
            is_hidden=name in hidden;logical=name.removeprefix('hidden_') if is_hidden else name
            strand=logical in strand_bones
            image=hidden[name] if is_hidden else images[name]
            z=list(hidden).index(name)-len(hidden) if is_hidden else order.index(name)
            part=dict(store(image,view,name),bone=BONES.get(logical,logical),logical_part=logical,z_index=z)
            if strand:
                part['bone']=strand_bones[logical];part['logical_part']='cloak';part['presentation_anchor']=joints[part['bone']]['position']
            if name=='staff':part['presentation_anchor']=joints['staff']['position']
            if is_hidden:
                part['hidden_material']=True
                domain=CASE/f'ownership/{view}_{name}_domain.png';domain.parent.mkdir(exist_ok=True)
                Image.fromarray(np.where(image[...,3]>0,255,0).astype(np.uint8)).save(domain)
                part['underlay_domain']={'file':str(domain.relative_to(CASE)),'sha256':digest(domain)}
            parts.append(part)
            if logical in MESHES:
                # All layers on a receiver share one field in source space.
                bounds=store(images[logical],view,logical)['bbox']
                mesh=layer(part,logical,bounds,joints,z,is_hidden,recipe=MESHES[logical]);meshes.append(mesh)
            elif is_hidden and not strand:
                reference=store(images[logical],view,logical)['offset'];part['presentation_anchor']=reference
            check=np.zeros_like(image);check[image[...,3]>0]=[255,255 if is_hidden else 0,0,255]
            p=CASE/f'checks/{view}/{name}.png';p.parent.mkdir(parents=True,exist_ok=True);Image.fromarray(check).crop(part['bbox']).save(p)
            checks[name]={'mask':str(p.relative_to(CASE)),'mask_offset':part['offset'],'z_index':z,'source':part['file'],
                          'rigid':logical not in MESHES,'source_sha256':digest(CASE/part['file'])}
        feet={}
        for side in ('near','far'):
            y,x=np.nonzero(images['foot_'+side][...,3]);feet[side]=[float(x[y==y.max()].mean())+.5,float(y.max()+1)]
        anchor=np.mean(list(feet.values()),axis=0).tolist()
        y,x=np.nonzero(images['staff'][...,3]);end=[float(x[y==y.max()].mean())+.5,float(y.max()+1)]
        groups={k:[n for n in ns if n in images] for k,ns in GROUPS.items()}
        groups['lower_body'] += [row['name'] for row in strand_specs]
        for name in hidden:
            for names in groups.values():
                if name.removeprefix('hidden_') in names:names.append(name)
        projections[view]={'forward':[(-1 if view=='front' else 1)*2/np.sqrt(5),(1 if view=='front' else -1)/np.sqrt(5)],'lean_sign':-1 if view=='front' else 1}
        held={'staff':{'hand':'hand_far','source_grip':joints['staff']['position'],'floor_end':end,'floor_line_y':anchor[1],
                       'follow_reference_bone':'pelvis','follow_hand_joint':True,'follow_zero_at_end':True,'follow_limit_deg':6.0}}
        # A torso child with a world-angle channel; source_grip is the hook itself.
        held['bell']={'hand':'torso','source_grip':joints['bell']['position']}
        layout={'version':2,'rig':'humanoid_v2','facing':view,'canvas_size':[255,255],'joints':joints,'parts':parts,'joint_meshes':meshes,
                'idle_groups':groups,'held_items':held,'held_drop_runtime':'res://assets/units/storm_cantor_cutout/held_drop.gd',
                'planted_during_death':True,'planted_foot_orientation_clips':['lay_the_choir','peal','broken_rhythm','call_the_spark','hit','death'],
                'ik_chains':[],'planted_bones':['foot_near','foot_far'],'source_labels':{n:[n.removeprefix('hidden_')] for n in list(hidden)+order},
                'painted_node_transforms':True,'stable_source_raster':True,'rigid_cloth_strands':strand_specs,
                'features':[],'strike_points':{'staff':[65.5,6.5] if view=='front' else [183.5,16.5]},
                'rest_source':f'source/{view}/rest.png','raw_rest_source':f'source/{view}/approved.png',
                'motion_data':'res://'+str(CASE.relative_to(ROOT)/'compiled_motion.json'),'proof_layers':checks,'proof_rest_holes':[], 'gait_leg_scale_max':1.22}
        layouts[view]=layout
        rest=Image.new('RGBA',(255,255))
        for part in sorted(parts,key=lambda p:p['z_index']):
            rest.alpha_composite(Image.open(CASE/part['file']).convert('RGBA'),tuple(part['offset']))
        rest.save(source/'rest.png')
        reports[view]={'tucks':[],'front_rest_mismatch_pixels':mismatch,'rest_mismatch_pixels':mismatch,'soles':feet,'anchor':anchor,
                       'head_top':int(np.nonzero(images['head'][...,3])[0].min()),'paint_sha256':digest(ROOT/reg['painting'])}
        own=CASE/f'ownership/{view}.png';own.parent.mkdir(exist_ok=True);Image.fromarray(labels).save(own)
    a=anatomy(layouts);write_json(CASE/'anatomy.json',a)
    from air_references import build as rest_air
    for view,l in layouts.items():
        rest_air(CASE,l)
        l['proof_joint_seams']=build_masks(CASE,l,{p['name']:source_pixels(CASE,p) for p in l['parts']},a)
        write_json(CASE/f'layouts/{view}.json',l)
    shutil.copyfile(DIRECTOR,CASE/'director_motion.json')
    from walk03_motion import revise_director
    revise_director(CASE/'director_motion.json')
    motion=clamp_limits(compile_motion(CASE/'director_motion.json','storm_cantor',layouts,projections))
    # Director text explicitly keeps the cloak still during the upper-body bob.
    # Its attachment remains on the torso for every other clip.
    for tracks in motion['view_tracks'].values():
        bob=next(t for t in tracks['idle'] if t['source']=='torso.lift_px')
        tracks['idle'].append(dict(source='cloak_root.lift_px', bone='cloak_root', channel='lift_px',
                                  keys=[dict(k,value=-k['value']) for k in bob['keys']],forward_mode='pixels'))
    from reach_budget import apply as reach_budget
    budgets=reach_budget(motion,layouts)
    write_json(CASE/'joint_budgets.json',budgets)
    from floor_contract import apply
    for view,layout in layouts.items():apply(layout,motion,CASE);write_json(CASE/f'layouts/{view}.json',layout)
    write_json(CASE/'compiled_motion.json',motion)
    write_json(CASE/'cutout.json',{'character_id':'storm_cantor','rig':'humanoid_v2','proof_geometry':{'canvas_size':640,'source_offset':192},
               'layouts':{v:f'layouts/{v}.json' for v in VIEWS},'direction_clips':['lay_the_choir','broken_rhythm','call_the_spark'],
               'clips':motion['clips'],'runtime_paths':['scripts/maquette_cutout_runtime/humanoid_motion.gd','scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
    write_json(CASE/'inputs.json',{**{v+'_job':f'spec/art_identity/jobs/storm_cantor/mq26_{v}' for v in VIEWS},
               'design_placeholders':budgets['placeholders'],'registration':'Independent source painting landmarks; maquette labels only',
               'protected':{n:digest(STAGED/n) for n in ('motion_tracks.json','front_body_underlay.png','rear_body_underlay.png')}})
    write_json(CASE/'proof/build.json',{**reports['front'],'views':reports,'native_pixels':False,'director_sha256':digest(DIRECTOR),'chosen_defaults':CHOSEN_DEFAULTS})
    promote(ROOT,CASE,ASSETS/'humanoid_v2',layouts)
    for view in VIEWS:
        path=ASSETS/f'humanoid_v2/{view}.json';production=read_json(path)
        production.pop('source_air_references',None)
        for part in production['parts']:part.pop('underlay_domain',None)
        write_json(path,production)
    for folder in (CASE,ASSETS/'humanoid_v2'):
        for p in folder.rglob('*.png'):
            if 'proof' not in p.relative_to(folder).parts:Path(str(p)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    for view in VIEWS:print(f'RR56 {view.upper()} REST: {reports[view]["rest_mismatch_pixels"]} px mismatch (source ownership; native pending)')

if __name__=='__main__':build()
