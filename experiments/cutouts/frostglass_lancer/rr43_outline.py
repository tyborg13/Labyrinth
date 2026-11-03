"""Director feedback 1: repaint the accepted partition, never segment it again.

The one-pixel edge comes from the complete registered painting. A cut's own
boundary is never an outline authority. The archive retains round 0's alpha,
hidden paint, geometry and treated production colours independently of this
repaint, so both derivation and tests can enforce the narrow change.
"""
from functools import lru_cache
import hashlib
import io
import json
from pathlib import Path
import shutil
import zipfile

import numpy as np
from PIL import Image

from rr37_case import CASE, PROJECT, ASSETS
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels

TONE = (20, 16, 21)  # Protected director recipe, step 4.
BASELINE = CASE/'rr43/outline_baseline.json'
JOB = PROJECT/'spec/art_identity/jobs/frostglass_lancer/mq14_rear_v2'


@lru_cache(maxsize=None)
def baseline_bytes(relative):
    record = read_json(BASELINE)
    archive = PROJECT/record['archive']
    if digest(archive) != record['archive_sha256']:
        raise ValueError('Changed accepted round-0 outline baseline')
    with zipfile.ZipFile(archive) as source:
        data = source.read(relative)
    if hashlib.sha256(data).hexdigest() != record['files'][relative]:
        raise ValueError('Changed baseline member: '+relative)
    return data


def baseline_image(path):
    return np.array(Image.open(io.BytesIO(baseline_bytes(str(Path(path).relative_to(PROJECT)))))).copy()


def outer_edge(alpha):
    padded = np.pad(alpha,1)
    return alpha & ~(padded[:-2,1:-1] & padded[2:,1:-1] & padded[1:-1,:-2] & padded[1:-1,2:])


def registration_paint():
    """Outline RGB cannot move the already accepted shaft axis or grip."""
    return baseline_image(CASE/'source/rear/processed.png')


def paint_mask(case, layout, part):
    approved = np.zeros((255,255),bool)
    if layout['facing']!='rear' or not layout.get('director_rear_outline'):
        return approved
    paint = np.array(Image.open(case/layout['rest_source']).convert('RGBA'))
    image = source_pixels(case,part)
    return outer_edge(paint[...,3]>0) & (image[...,3]>0) & np.all(image[...,:3]==TONE,axis=-1)


def density_declarations(layouts):
    """Raw house edge; exact accepted production RGB everywhere else."""
    layout=layouts['rear']
    if not layout.get('director_rear_outline'):return {}
    folder=CASE/'rr43/outline_production';folder.mkdir(parents=True,exist_ok=True)
    paint=np.array(Image.open(JOB/'processed.png').convert('RGBA'))
    mask=folder/'outer_edge.png'
    Image.fromarray(outer_edge(paint[...,3]>0).astype('uint8')*255).save(mask)
    result={}
    for part in layout['parts']:
        target=ASSETS/'humanoid_v2/rear'/Path(part['file']).name
        old=folder/target.name
        old.write_bytes(baseline_bytes(str(target.relative_to(PROJECT))))
        result[str(target.relative_to(PROJECT))]={'mask':{'path':str(mask.relative_to(PROJECT)),'sha256':digest(mask)},
            'source_offset':part['offset'],
            'outside':{'path':str(old.relative_to(PROJECT)),'sha256':digest(old),'offset':part['offset']}}
    return result


def derive():
    record=read_json(BASELINE)
    if digest(JOB/'processed.png')!=record['processed_rear_sha256']:
        raise ValueError('Expected the protected outlined rear master')
    old=registration_paint()
    paint=np.array(Image.open(JOB/'processed.png').convert('RGBA'))
    paint[paint[...,3]==0]=0  # Same invisible transparent-clear normalization as round 0.
    if not np.array_equal(old[...,3],paint[...,3]):raise ValueError('Director repaint changed alpha')
    edge=outer_edge(paint[...,3]>0)
    changed=np.any(old!=paint,axis=-1)
    if int(changed.sum())!=1020 or np.any(changed & ~edge) or not np.all(paint[edge,:3]==TONE):
        raise ValueError('Director repaint is not exactly the supplied 1020-pixel house edge')
    layout=read_json(CASE/'layouts/rear.json')
    layout['director_rear_outline']={'recipe_sha256':record['recipe_sha256'],
        'processed_sha256':record['processed_rear_sha256'],'authority':'whole registered silhouette; four neighbours'}
    Image.fromarray(paint).save(CASE/'source/rear/processed.png')
    shutil.copyfile(JOB/'processed.json',CASE/'source/rear/processed.json')
    rows={}
    from maquette_motion.material_palette import rules,outline_class
    definition=rules(CASE,'rear')
    for part in layout['parts']:
        path=CASE/part['file'];before=baseline_image(path)
        x,y=part['offset'];height,width=before.shape[:2]
        selected=edge[y:y+height,x:x+width] & (before[...,3]>0)
        after=before.copy();after[selected,:3]=TONE
        Image.fromarray(after).save(path)
        checks=baseline_image(CASE/layout['proof_layers'][part['name']]['mask'])
        # R/A remain immutable ownership. G denotes procedural fill; these
        # particular edge texels are now exact director paint, not donors.
        if part.get('hidden_material'):checks[selected,1]=0
        checks[...,2]=np.where(outline_class(after,definition)&(checks[...,3]>0),255,0)
        Image.fromarray(checks).save(CASE/layout['proof_layers'][part['name']]['mask'])
        layout['proof_layers'][part['name']]['source_sha256']=digest(path)
        rows[part['name']]={'file':part['file'],'sha256':digest(path),
            'alpha_sha256':hashlib.sha256(after[...,3].tobytes()).hexdigest(),
            'outlined_pixels':int(selected.sum()),'hidden_material':bool(part.get('hidden_material'))}
    write_json(CASE/'layouts/rear.json',layout)
    visible={p['name']:source_pixels(CASE,p) for p in layout['parts'] if not p.get('hidden_material')}
    from rr37_surfaces import provenance
    provenance(CASE,layout,visible,definition)
    # Reconstitute the rest independently; no per-piece edge expansion.
    rest=Image.new('RGBA',(255,255))
    for part in sorted(layout['parts'],key=lambda p:p['z_index']):
        rest.alpha_composite(Image.fromarray(source_pixels(CASE,part)))
    mismatch=int(np.any(np.array(rest)!=paint,axis=-1).sum())
    if mismatch:raise ValueError(f'Outlined rest mismatch: {mismatch}')
    manifest={'processed_sha256':digest(JOB/'processed.png'),'edge_pixels':int(edge.sum()),
        'changed_visible_rgb_pixels':int(changed.sum()),'source_rest_mismatch_pixels':mismatch,
        'partition':'byte-identical alpha masks, offsets, meshes, joints and recipes from round 0','parts':rows}
    write_json(CASE/'rr43/rear_outline_manifest.json',manifest)
    print(f'RR43 HOUSE OUTLINE: PASS ({int(edge.sum())} whole-silhouette pixels; masks unchanged; source rest=0px)')
    return manifest


def invariant_errors(source_root=CASE, production_root=ASSETS/'humanoid_v2'):
    """Compare both scopes to the retained accepted paint, not this writer."""
    errors=[]
    master=np.array(Image.open(JOB/'processed.png').convert('RGBA'))
    edge=outer_edge(master[...,3]>0)
    for scope,root,layout_path,baseline_path in (
            ('source',source_root,'layouts/rear.json',CASE/'layouts/rear.json'),
            ('production',production_root,'rear.json',ASSETS/'humanoid_v2/rear.json')):
        old=json.loads(baseline_bytes(str(baseline_path.relative_to(PROJECT))))
        current=read_json(root/layout_path)
        from rr45_preservation import prior_layout
        try:
            geometry = prior_layout(current)
        except ValueError as error:
            errors.append(scope+': '+str(error))
            geometry = current
        for key in ('parts','joint_meshes','joints','held_items','gait_continuations','clip_continuations'):
            if geometry[key]!=old[key]:errors.append(scope+': accepted geometry/recipe changed: '+key)
        rest=Image.new('RGBA',(255,255))
        for part in old['parts']:
            canonical=(CASE if scope=='source' else ASSETS/'humanoid_v2')/part['file']
            before=baseline_image(canonical)
            after=np.array(Image.open(root/part['file']).convert('RGBA'))
            if after.shape!=before.shape:
                errors.append(scope+'/'+part['name']+': crop changed');continue
            x,y=part['offset'];height,width=after.shape[:2]
            local=edge[y:y+height,x:x+width] & (before[...,3]>0)
            if not np.array_equal(before[...,3],after[...,3]):errors.append(scope+'/'+part['name']+': alpha changed')
            if not np.array_equal(before[~local],after[~local]):errors.append(scope+'/'+part['name']+': paint changed outside whole silhouette edge')
            if not np.all(after[local,:3]==TONE):errors.append(scope+'/'+part['name']+': missing house edge')
        for part in sorted(current['parts'],key=lambda p:p['z_index']):
            rest.alpha_composite(Image.fromarray(source_pixels(root,part)))
        expected=np.array(Image.open(root/current['rest_source']).convert('RGBA'))
        if scope=='source':
            expected=master.copy()
            expected[expected[...,3]==0]=0
        if not np.array_equal(np.array(rest),expected):errors.append(scope+': rest assembly mismatch')
    return errors


def seal_manifest():
    """Finish the source manifest after the density step, before binding proof."""
    errors=invariant_errors()
    if errors:raise ValueError('Cannot seal rear outline manifest: '+str(errors))
    path=CASE/'rr43/rear_outline_manifest.json'
    manifest=read_json(path)
    layout=read_json(ASSETS/'humanoid_v2/rear.json')
    manifest['production']={p['name']:{'file':p['file'],
        'sha256':digest(ASSETS/'humanoid_v2'/p['file'])} for p in layout['parts']}
    manifest['production_rest_sha256']=digest(ASSETS/'humanoid_v2/rear/rest.png')
    manifest['production_assembly_mismatch_pixels']=0  # Rest equality is enforced above.
    manifest['preservation_errors']=errors
    write_json(path,manifest)
    print('RR43 OUTLINE MANIFEST: PASS (source/production invariants exact; production rest=0px)')
    return manifest


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seal-manifest',action='store_true')
    args=parser.parse_args()
    if args.seal_manifest:seal_manifest()
    else:derive()
