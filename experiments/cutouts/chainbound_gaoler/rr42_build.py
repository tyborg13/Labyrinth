"""Deterministic rr-38 fork; supplied underlay replaces generated backing."""
import shutil
import numpy as np
from PIL import Image
from rr42_underlay import CASE, BASE_CASE, ASSETS, PROJECT, inputs, domains, retire_recipes, REMOVED_FILLS, authority_for, repairs
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.promotion import promote

BASELINE = CASE.parent/'rr42_baseline'


def snapshot():
    """Retain only Gaoler production baseline; never snapshot a previous rebuild."""
    present=[(BASELINE/(v+'.json')).exists() for v in ('front','rear')]
    if all(present): return
    if any(present): raise ValueError('Incomplete rr-42 baseline; do not resnapshot modified production')
    BASELINE.mkdir(parents=True,exist_ok=True)
    for view in ('front','rear'):
        layout = read_json(ASSETS/f'humanoid_v2/{view}.json')
        write_json(BASELINE/(view+'.json'), {key:layout[key] for key in ('facing','canvas_size','parts','rest_source')})
        for part in layout['parts']:
            target = BASELINE/part['file']; target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(ASSETS/'humanoid_v2'/part['file'],target)


def build():
    snapshot()
    CASE.mkdir(parents=True,exist_ok=True)
    for name in ('anatomy.json','inputs.json','director_motion.json','compiled_motion.json','cutout.json','material_contract.json'):
        shutil.copyfile(BASE_CASE/name,CASE/name)
    for folder in ('checks','features','holes','seams','source','tucks','ownership','uncovered','pieces'):
        shutil.copytree(BASE_CASE/folder,CASE/folder,dirs_exist_ok=True)
    (CASE/'proof').mkdir(exist_ok=True)
    from rr38_case import DIRECTOR
    shutil.copyfile(DIRECTOR,CASE/'director_motion.json')
    paint,masks = inputs(); authority = np.logical_or.reduce(list(masks.values())); targets = domains()
    anatomy = read_json(CASE/'anatomy.json')
    report = {'native_pixels':False,'director_files':read_json(PROJECT/'spec/peer_benchmark/staged/rr-42/provenance.json')['files'],
              'ownership_rule':'existing body backing z order, then registered storage domain; exclude vacating limbs/items',
              'views':{},'clamps':[]}
    for view in ('front','rear'):
        layout = read_json(BASE_CASE/f'layouts/{view}.json')
        layout['motion_data'] = 'res://'+str(CASE.relative_to(PROJECT)/'compiled_motion.json')
        images = {p['name']:source_pixels(BASE_CASE,p) for p in layout['parts']}
        removed = {}
        for name,image in images.items():
            if name in REMOVED_FILLS:
                # Retire generated source islands, preserving connected backing.
                # Posed remnants are inventoried by the calibrated sweep.
                from maquette_motion.silhouette import components
                visible=images[name.removeprefix('hidden_')]
                labels,groups=components((visible[...,3]>0)|(image[...,3]>0),8)
                islands=(labels>0)&(labels!=groups[0][0]) if groups else np.zeros((255,255),bool)
                removed[name]=int((islands&(image[...,3]>0)).sum())
                image[islands]=0
            if view=='front' and name.startswith('hidden_'):
                logical=next(p['logical_part'] for p in layout['parts'] if p['name']==name)
                image[authority_for(logical)] = 0
        if view=='front':
            for name,target in targets.items(): images['hidden_'+name][target] = paint[target]
        for row in repairs() if view=='front' else []:
            x,y=row['uv']; images[row['part']][y,x]=paint[y,x]
        from rr42_fragments import apply as attach_fragments
        fragments=attach_fragments(view,images)
        for part in layout['parts']:
            name = part['name']; image = images[name]
            original = source_pixels(BASE_CASE,part)
            changed = np.any(image!=original,axis=-1)
            # Keep original crop origin modulo the existing two-pixel lattice.
            bounds = part['bbox'].copy(); yy,xx = np.nonzero(image[...,3])
            if len(xx):
                for index,edge in ((0,int(xx.min())),(1,int(yy.min()))):
                    bounds[index] -= max(0,int(np.ceil((bounds[index]-edge)/2)))*2
                for index,edge in ((2,int(xx.max()+1)),(3,int(yy.max()+1))):
                    bounds[index] += max(0,int(np.ceil((edge-bounds[index])/2)))*2
            old_offset=part['offset'].copy()
            if bounds[:2]!=old_offset:part.setdefault('presentation_anchor',old_offset)
            part['bbox'],part['offset'] = bounds,bounds[:2]
            x,y,x1,y1 = bounds
            Image.fromarray(image).crop(bounds).save(CASE/part['file'])
            for index,mesh in enumerate(layout['joint_meshes']):
                if mesh['name'] != name: continue
                visible = next(p for p in layout['parts'] if p['name']==part['logical_part'])
                old_visible=next(p for p in read_json(BASE_CASE/f'layouts/{view}.json')['parts'] if p['name']==part['logical_part'])
                rebuilt=layer(part,part['logical_part'],old_visible['bbox'],layout['joints'],part['z_index'],bool(part.get('hidden_material')),recipe=anatomy['meshes'][part['logical_part']])
                if part['bbox']!=old_visible['bbox'] or part.get('hidden_material'):
                    rebuilt['weight_bounds']=old_visible['bbox']
                layout['joint_meshes'][index]=rebuilt
            checks = np.zeros_like(image); active = image[...,3]>0
            checks[active] = [255,255 if part.get('hidden_material') else 0,0,255]
            from maquette_motion.material_palette import outline_class,rules
            checks[active & outline_class(image,rules(CASE,view)),2] = 255
            record = layout['proof_layers'][name]
            Image.fromarray(checks).crop(bounds).save(CASE/record['mask'])
            record.update(mask_offset=part['offset'],source_sha256=digest(CASE/part['file']))
            if not part.get('hidden_material'):
                Image.fromarray(active.astype('uint8')*255).save(CASE/f'uncovered/donor_{view}_{name}.png')
            # A density partition copies changed source exactly, retaining prior
            # treated production everywhere else, including visible paint.
            density_authority=changed.copy()
            if view=='front' and part.get('hidden_material'):
                density_authority |= authority_for(part['logical_part'])
            mask = np.zeros_like(image); mask[density_authority] = 255
            path = CASE/f'ownership/rr42_{view}_{name}.png'; Image.fromarray(mask).save(path)
        retired = retire_recipes(layout)
        rest = Image.new('RGBA',(255,255))
        for part in sorted(layout['parts'],key=lambda p:p['z_index']): rest.alpha_composite(Image.fromarray(images[part['name']]))
        rest.save(CASE/layout['rest_source'])
        from rr42_references import rebuild as rebuild_references
        references=rebuild_references(CASE,layout,images,anatomy,rest)
        write_json(CASE/f'layouts/{view}.json',layout)
        report['views'][view] = {'removed_fill_pixels':removed,'retired_continuation_targets':retired,
                               'rest_sha256':digest(CASE/layout['rest_source']),'fragments':fragments,'references':references}
    from humanoid_cutout.compiler import compile_motion
    layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
    projection=read_json(BASE_CASE/'compiled_motion.json')['projection']
    compiled=compile_motion(CASE/'director_motion.json','chainbound_gaoler',layouts,projection)
    from rr42_motion import apply as clamp_channels
    compiled=clamp_channels(compiled)
    report['clamps']=read_json(CASE.parent/'rr42_feedback1_clamps.json')['channels']
    write_json(CASE/'compiled_motion.json',compiled)
    definition=read_json(CASE/'cutout.json'); definition['design_placeholders']={}
    definition['clips']=compiled['clips']
    write_json(CASE/'cutout.json',definition)
    write_json(CASE/'proof/build.json',read_json(BASE_CASE/'proof/build.json'))
    from rr42_tucks import apply as rebind_tucks
    rebind_tucks(CASE)
    write_json(CASE/'proof/partition.json',report)
    layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
    promote(PROJECT,CASE,ASSETS/'humanoid_v2',layouts)
    for root in (CASE,BASELINE):
        for path in root.rglob('*.png'):
            if 'proof' not in path.relative_to(root).parts:
                type(path)(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    print('RR42 PARTITION BUILD: PASS (protected paint; retired generated coat/boot islands; native proof pending)')


if __name__=='__main__': build()
