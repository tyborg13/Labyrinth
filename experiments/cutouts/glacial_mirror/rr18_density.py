"""Adopt only the Mirror closure; native rest certification belongs to the owner."""
from pathlib import Path
import subprocess
import sys
from rr18_case import PROJECT, CASE, ASSETS
from cutout_pipeline.cases import read_json, write_json
from pixel_density import metrics, strength
from PIL import Image

DENSITY = PROJECT / 'spec/assets/board_pixel_density'
ID = 'glacial_mirror_cutout'


def register(refresh_sources=False):
    path = DENSITY / 'registry.json'
    registry = read_json(path)
    entry = next((e for e in registry['entries'] if e['id'] == ID), None)
    if entry is None:
        entry = {'id': ID, 'unit_type':'glacial_mirror','kind':'rig','dir':str(ASSETS.relative_to(PROJECT)),
            'rig_script':str((ASSETS/'rig.gd').relative_to(PROJECT)), 'paths':[], 'frames':None, 'r':1.0,
            'r_derivation':{'path':'data/enemies.json','key':'glacial_mirror.art_scale','expression':'art_scale (default 1.0)'},
            'facings':{},'rest_paths':{}}
        registry['entries'].append(entry)
    entry['paths'] = sorted(str(p.relative_to(PROJECT)) for view in ('front','rear')
        for p in (ASSETS/'humanoid_v2'/view).glob('*.png') if p.name != 'rest.png')
    adopted = list(entry['paths'])
    for view in ('front','rear'):
        rest = str((ASSETS/'humanoid_v2'/view/'rest.png').relative_to(PROJECT))
        share = metrics(Image.open(PROJECT/rest).convert('RGBA'))['orphan_share']
        t = strength(share); grid = round(t/entry['r'],2)
        entry['facings'][view] = {'measurement_path':rest,'orphan_share':share,'t':t,'grid':grid,'mode':'regrid' if grid>=1.2 else 'clean'}
        entry['rest_paths'][view] = [rest]
        layout = read_json(ASSETS/'humanoid_v2'/(view+'.json'))
        for part in layout['parts'] + layout['joint_meshes']: part['file'] = 'humanoid_v2/'+part['file']
        layout['rest_source'] = 'humanoid_v2/'+layout['rest_source']
        write_json(ASSETS/(view+'.json'),layout)
        registry['excluded_paths'][rest] = {'category':'other','reason':'Derived Mirror assembly snapshot; separately bound in rest_paths, never live paint.'}
        adopted.append(rest)
    write_json(path,registry)
    missing = [p for p in adopted if not (DENSITY/'sources'/p).exists()]
    changed = [p for p in adopted if (DENSITY/'sources'/p).exists() and (PROJECT/p).read_bytes() != (DENSITY/'sources'/p).read_bytes()]
    if changed and not refresh_sources: raise ValueError('Case rebuild requires explicit --refresh-sources: '+str(changed))
    if changed:
        if any('/glacial_mirror_cutout/humanoid_v2/' not in p for p in changed): raise ValueError('Refusing out-of-unit source refresh')
        subprocess.run([sys.executable,'tools/process_board_density.py','--adopt',*changed,'--force-adopt'],cwd=PROJECT,check=True)
    if missing: subprocess.run([sys.executable,'tools/process_board_density.py','--adopt',*missing],cwd=PROJECT,check=True)
    subprocess.run([sys.executable,'tools/process_board_density.py','--only',ID],cwd=PROJECT,check=True)
    from humanoid_cutout.integration import record
    record(PROJECT,CASE,ASSETS)
    print('RR18 DENSITY PAINT: PASS (both views adopted/processed; native rest records pending director)')

if __name__ == '__main__':
    if len(sys.argv)>1 and sys.argv[1]=='seal':
        from humanoid_cutout.integration import record
        pending=record(PROJECT,CASE,ASSETS)
        if pending: raise ValueError('Native rest rebake still pending: '+str(pending))
        print('RR18 DENSITY REST RECORDS: PASS (2 director-rendered views)')
    else: register('--refresh-sources' in sys.argv)
