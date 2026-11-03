"""rr-42 source partitions, scoped to rr-44; CPU rests are never native proof."""
import subprocess
import sys
from pathlib import Path
import numpy as np
from PIL import Image
from rr44_case import PROJECT, BASE, CASE, ASSETS
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.promotion import promote
from rr38_proof_case import build as proof_case

DENSITY = PROJECT/'spec/assets/board_pixel_density'
BASELINE = CASE/'baseline'
ID = 'chainbound_gaoler_cutout'
PROOF_CASE = CASE/'proof/production_case'


def snapshot():
    if (BASELINE/'manifest.json').exists(): return
    BASELINE.mkdir(parents=True,exist_ok=True)
    paths = []
    for view in ('front','rear'):
        path = ASSETS/f'humanoid_v2/{view}.json'
        data = subprocess.check_output(['git','show','HEAD:'+str(path.relative_to(PROJECT))],cwd=PROJECT)
        (BASELINE/f'{view}.json').write_bytes(data)
        for part in read_json(BASELINE/f'{view}.json')['parts']:
            target = BASELINE/part['file']; target.parent.mkdir(parents=True,exist_ok=True)
            path = ASSETS/'humanoid_v2'/part['file']
            target.write_bytes(subprocess.check_output(['git','show','HEAD:'+str(path.relative_to(PROJECT))],cwd=PROJECT))
            paths.append(target)
    write_json(BASELINE/'manifest.json',dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=PROJECT,text=True).strip(),
                files={str(p.relative_to(BASELINE)):digest(p) for p in paths}))


def build():
    snapshot()
    layouts = {v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
    promote(PROJECT,CASE,ASSETS/'humanoid_v2',layouts)
    registry = read_json(DENSITY/'registry.json'); entry = next(e for e in registry['entries'] if e['id']==ID)
    active={str((ASSETS/f'humanoid_v2/{view}/{p["name"]}.png').relative_to(PROJECT)) for view,l in layouts.items() for p in l['parts']}
    obsolete=[p for p in entry['paths'] if Path(p).name.startswith('joint_cap_') and p not in active]
    if obsolete:
        manifest=read_json(DENSITY/'outputs.json')
        for relative in obsolete:
            for path in (PROJECT/relative,DENSITY/'sources'/relative):
                path.unlink(missing_ok=True);Path(str(path)+'.import').unlink(missing_ok=True)
            manifest.pop(relative,None)
        entry['paths']=[p for p in entry['paths'] if p not in obsolete]
        write_json(DENSITY/'outputs.json',manifest)
    partitions = {}
    for view,layout in layouts.items():
        old = {p['name']:p for p in read_json(BASELINE/f'{view}.json')['parts']}
        for part in layout['parts']:
            name = part['name']; before = old.get(name,old[part['logical_part']]); mask = CASE/f'ownership/rr44_{view}_{name}.png'
            target = ASSETS/f'humanoid_v2/{view}/{name}.png'
            relative=str(target.relative_to(PROJECT))
            if relative not in entry['paths']:entry['paths'].append(relative)
            partitions[str(target.relative_to(PROJECT))] = dict(mask=dict(path=str(mask.relative_to(PROJECT)),sha256=digest(mask)),
                source_offset=part['offset'],outside=dict(path=str((BASELINE/before['file']).relative_to(PROJECT)),sha256=digest(BASELINE/before['file']),offset=before['offset']))
            baseline = np.zeros((255,255,4),np.uint8)
            raw = np.asarray(Image.open(BASELINE/before['file']).convert('RGBA'))
            bx,by = before['offset']; baseline[by:by+raw.shape[0],bx:bx+raw.shape[1]] = raw
            active = np.asarray(Image.open(mask).convert('L'))>0
            image = np.asarray(Image.open(target).convert('RGBA')).copy(); x,y,x1,y1=part['bbox']
            image[~active[y:y1,x:x1]] = baseline[y:y1,x:x1][~active[y:y1,x:x1]]
            Image.fromarray(image).save(target)
    entry['source_partitions'] = partitions
    entry['paths'].sort()
    from pixel_density import metrics, strength
    for view,layout in layouts.items():
        share=metrics(Image.open(CASE/layout['rest_source']).convert('RGBA'))['orphan_share']
        treatment=strength(share); grid=round(treatment/entry['r'],2)
        entry['facings'][view].update(orphan_share=share,t=treatment,grid=grid,mode='regrid' if grid>=1.2 else 'clean')
    write_json(DENSITY/'registry.json',registry)
    rests=[p for group in entry['rest_paths'].values() for p in group]
    subprocess.run([sys.executable,'tools/process_board_density.py','--force-adopt','--adopt',*entry['paths'],*rests],cwd=PROJECT,check=True)
    subprocess.run([sys.executable,'tools/process_board_density.py','--only',ID],cwd=PROJECT,check=True)
    import rr38_density
    rr38_density.CASE=CASE
    rr38_density.expected_rests()
    proof_case(case=CASE,output=PROOF_CASE)
    print('RR44 DENSITY PARTITIONS: PASS (exact director paint inside; prior approved production outside)')


def rests():
    # The tested rr-42 assembler already distinguishes CPU equivalence from
    # native capture. Bind its parameterized globals only for this CLI run.
    import rr42_density
    rr42_density.CASE=CASE; rr42_density.PROOF_CASE=PROOF_CASE
    rr42_density.rests(task_id='rr-44', timeout_s=85)


def seal():
    import rr38_density
    rr38_density.CASE=CASE
    return rr38_density.seal()


if __name__=='__main__':
    if '--rests' in sys.argv: rests()
    elif '--seal-native' in sys.argv:
        if seal(): raise ValueError('Native density rebake remains pending')
    else: build()
