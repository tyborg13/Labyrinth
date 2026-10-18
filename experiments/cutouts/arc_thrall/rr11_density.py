"""Register/adopt the promoted Thrall only; native rest certification is separate."""
import json
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from pixel_density import metrics, strength
from PIL import Image

ASSETS = PROJECT / 'assets/units/arc_thrall_cutout'
DENSITY = PROJECT / 'spec/assets/board_pixel_density'
ID = 'arc_thrall_cutout'


def register(refresh_sources=False):
    path = DENSITY / 'registry.json'
    registry = read_json(path)
    entry = next(e for e in registry['entries'] if e['id'] == ID)
    new_paths = sorted(str(p.relative_to(PROJECT)) for view in ('front', 'rear')
                       for p in (ASSETS / 'humanoid_v2' / view).glob('*.png') if p.name != 'rest.png')
    entry['paths'] = sorted(set(entry['paths']) | set(new_paths))
    adopted = list(new_paths)
    for view in ('front', 'rear'):
        rest = str((ASSETS / 'humanoid_v2' / view / 'rest.png').relative_to(PROJECT))
        old_rests = entry['rest_paths'][view]
        for old in old_rests:
            if old != rest:
                registry['excluded_paths'][old] = {'category': 'never_drawn',
                    'reason': 'Retained rr-07 Thrall rest; humanoid_v2 replaces its production board and UI registration.'}
        share = metrics(Image.open(PROJECT / rest).convert('RGBA'))['orphan_share']
        t = strength(share)
        grid = round(t / entry['r'], 2)
        entry['facings'][view] = {'measurement_path': rest, 'orphan_share': share, 't': t,
                                 'grid': grid, 'mode': 'regrid' if grid >= 1.2 else 'clean'}
        entry['rest_paths'][view] = [rest]
        # The density rebaker reads the owning family's layout to refresh the
        # rest fingerprint. The runtime's identical layout lives in v2.
        layout = read_json(ASSETS / 'humanoid_v2' / (view + '.json'))
        for part in layout['parts'] + layout['joint_meshes']:
            part['file'] = 'humanoid_v2/' + part['file']
        layout['rest_source'] = 'humanoid_v2/' + layout['rest_source']
        write_json(ASSETS / (view + '.json'), layout)
        registry['excluded_paths'][rest]={'category':'other','reason':'Derived humanoid_v2 rest snapshot, separately bound in rest_paths; never live paint.'}
        adopted.append(rest)
    entry['preserved_rest_paths'] = sorted(set(entry.get('preserved_rest_paths',[])) |
        {str((ASSETS/view/'rest.png').relative_to(PROJECT)) for view in ('front','rear')})
    write_json(path, registry)
    manifest = read_json(DENSITY / 'outputs.json')
    for old in registry['excluded_paths']:
        if old.startswith('assets/units/arc_thrall_cutout/humanoid_v2/'):
            manifest.pop(old, None)
    write_json(DENSITY / 'outputs.json', manifest)
    missing = [p for p in adopted if not (DENSITY / 'sources' / p).exists()]
    changed = [p for p in adopted if (DENSITY / 'sources' / p).exists() and
               (PROJECT / p).read_bytes() != (DENSITY / 'sources' / p).read_bytes()]
    if changed and not refresh_sources:
        raise ValueError('Untouched sources already exist with different bytes; inspect before deliberate --force-adopt: ' + str(changed))
    if changed:
        # Only the new case-owned v2 closure is eligible for this explicit
        # rebuild operation; old rr-07 sources remain protected.
        if any('/arc_thrall_cutout/humanoid_v2/' not in p for p in changed):
            raise ValueError('Refusing to refresh sources outside the rr-11 closure')
        subprocess.run([sys.executable, 'tools/process_board_density.py', '--adopt', *changed, '--force-adopt'], cwd=PROJECT, check=True)
    if missing:
        subprocess.run([sys.executable, 'tools/process_board_density.py', '--adopt', *missing], cwd=PROJECT, check=True)
    subprocess.run([sys.executable, 'tools/process_board_density.py', '--only', ID], cwd=PROJECT, check=True)
    from humanoid_cutout.integration import record
    record(PROJECT, PROJECT/'experiments/cutouts/arc_thrall/rr11', ASSETS)
    print('RR11 DENSITY PAINT: PASS (both views adopted/processed; native rest records pending director)')


if __name__ == '__main__':
    if len(sys.argv)>1 and sys.argv[1]=='seal':
        from humanoid_cutout.integration import record
        pending=record(PROJECT,PROJECT/'experiments/cutouts/arc_thrall/rr11',ASSETS)
        if pending: raise ValueError('Native rest rebake still pending: '+str(pending))
        print('RR11 DENSITY REST RECORDS: PASS (2 director-rendered views)')
    else: register('--refresh-sources' in sys.argv)
