"""Bind native proof to exact density-treated production paint, like rr-18.

The editable source case retains its 0px approved-painting rest. This derived
case has the same geometry/masks but the actual production paint and rest.
"""
from pathlib import Path
import shutil
import numpy as np
from PIL import Image
from rr37_case import CASE, ASSETS
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules, outline_class
from humanoid_cutout.native_defects import packed
from humanoid_cutout.gait_continuations import nearest_donors

PROOF_CASE = CASE / 'proof/production_case'


def copy_if_changed(source, target):
    source,target=Path(source),Path(target)
    if target.exists() and source.read_bytes()==target.read_bytes(): return str(target)
    return shutil.copyfile(source,target)


def build():
    PROOF_CASE.mkdir(exist_ok=True)
    for name in ('anatomy.json','inputs.json','cutout.json','director_motion.json','compiled_motion.json','rr41_exposure_repairs.json'):
        copy_if_changed(CASE/name,PROOF_CASE/name)
    for folder in ('checks','features','holes','seams','tucks','ownership','uncovered'):
        shutil.copytree(CASE/folder,PROOF_CASE/folder,dirs_exist_ok=True,copy_function=copy_if_changed)
    definition=read_json(CASE/'cutout.json');definition['paint_scope']='exact density-treated production parts'
    write_json(PROOF_CASE/'cutout.json',definition)
    contract={'views':{},'acceptance':'director native 2x review required; palettes bound to own source material/density derivation'}
    report={}
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');prod=read_json(ASSETS/f'humanoid_v2/{view}.json')
        production_parts={p['name']:p for p in prod['parts']}
        palettes={};rest=Image.new('RGBA',(255,255));part_hashes={}
        for part in sorted(layout['parts'],key=lambda p:p['z_index']):
            name=part['name'];source=ASSETS/'humanoid_v2'/production_parts[name]['file'];target=PROOF_CASE/part['file']
            target.parent.mkdir(parents=True,exist_ok=True);copy_if_changed(source,target)
            raw=np.asarray(Image.open(CASE/part['file']).convert('RGBA'));treated=np.asarray(Image.open(target).convert('RGBA'))
            if not np.array_equal(raw[...,3],treated[...,3]): raise ValueError('Density changed alpha ownership: '+name)
            rest.alpha_composite(Image.fromarray(treated),tuple(part['offset']))
            record=layout['proof_layers'][name];record['source_sha256']=digest(target)
            mask=PROOF_CASE/record['mask'];checks=np.asarray(Image.open(mask).convert('RGBA')).copy()
            checks[...,2]=np.where(outline_class(treated,rules(CASE,view)) & (checks[...,3]>0),255,0)
            Image.fromarray(checks).save(mask)
            # Every treated continuation was derived independently from its
            # own source material. Bind that exact resulting palette, rather
            # than incorrectly compare regridded colours with the raw palette.
            piece=part['logical_part'];palettes.setdefault(piece,set()).update(map(int,np.unique(packed(treated)[treated[...,3]>0])))
            part_hashes[name]=digest(source)
        path=PROOF_CASE/f'source/{view}/processed.png';path.parent.mkdir(parents=True,exist_ok=True);rest.save(path)
        if layout['rest_source'] != str(path.relative_to(PROOF_CASE)):
            # rr-54 retains the original source painting and references a
            # separately assembled rear rest after the shaft-order repair.
            rest.save(PROOF_CASE / layout['rest_source'])
        # Preserve the director's semantic clean-outline palette verbatim.
        # A treated-rest percentile alone does not identify its keyed tone.
        copy_if_changed(CASE/f'source/{view}/processed.json',path.with_suffix('.json'))
        if rest.tobytes()!=Image.open(ASSETS/'humanoid_v2'/prod['rest_source']).convert('RGBA').tobytes():
            raise ValueError('Production rest differs from its composed parts: '+view)
        # Outline classification must use the treated rest's own cutoff.
        # Reusing the source-paint cutoff would miss density-darkened bands.
        definition=rules(PROOF_CASE,view)
        for part in layout['parts']:
            treated=np.asarray(Image.open(PROOF_CASE/part['file']).convert('RGBA'))
            mask=PROOF_CASE/layout['proof_layers'][part['name']]['mask']
            checks=np.asarray(Image.open(mask).convert('RGBA')).copy()
            checks[...,2]=np.where(outline_class(treated,definition)&(checks[...,3]>0),255,0)
            Image.fromarray(checks).save(mask)
        for field in ('gait_continuations','clip_continuations'):
            tables=([layout.get(field,{})] if field=='gait_continuations' else list(layout.get(field,{}).values()))
            parts={p['name']:p for p in layout['parts']}
            for table in tables:
                for name,recipe in list(table.items()):
                    targets={(x,y) for x,y,_,_ in recipe['texels']}
                    rebound=nearest_donors(PROOF_CASE,layout,parts[name],targets)
                    if 'clips' in recipe: rebound['clips']=recipe['clips']
                    table[name]=rebound
            if field in layout: prod[field]=layout[field]
        write_json(ASSETS/f'humanoid_v2/{view}.json',prod)
        layout['motion_data']='res://'+str(PROOF_CASE.relative_to(CASE.parents[3])/'compiled_motion.json')
        write_json(PROOF_CASE/f'layouts/{view}.json',layout)
        report[view]={'rest_sha256':digest(path),'part_sha256':part_hashes}
        contract['views'][view]={'floor_pieces':['foot_near','foot_far','leg_near','leg_far'],
            'cloth_pieces':['cape_near','cape_far','tabard'],
            'interior_palettes':{n:sorted(p) for n,p in palettes.items()}}
    build=read_json(CASE/'proof/build.json');build['paint_scope']='production rest, independently composed from treated parts'
    write_json(PROOF_CASE/'proof/build.json',build)
    write_json(PROOF_CASE/'material_contract.json',contract)
    write_json(PROOF_CASE/'production_binding.json',report)
    write_json(CASE/'proof/production_binding.json',report)
    for path in PROOF_CASE.rglob('*.png'): Path(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    print('RR37 PRODUCTION PROOF CASE: PASS (exact treated paint; alpha ownership unchanged; independently composed rests)')


if __name__=='__main__':
    from pathlib import Path
    build()
