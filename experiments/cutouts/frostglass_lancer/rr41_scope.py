"""Prove that shared records changed only for this Lancer repair."""
import json
import subprocess
from rr37_case import PROJECT, CASE
from cutout_pipeline.cases import read_json, write_json

PREFIX = 'assets/units/frostglass_lancer_cutout/'
ID = 'frostglass_lancer_cutout'


def original(path):
    return json.loads(subprocess.check_output(['git', 'show', 'HEAD:'+path], cwd=PROJECT))


def verify():
    directory = 'spec/assets/board_pixel_density/'
    before = original(directory+'registry.json')
    after = read_json(PROJECT/(directory+'registry.json'))
    for registry in (before, after):
        registry['entries'] = [e for e in registry['entries'] if e['id'] != ID]
        registry['excluded_paths'] = {k:v for k,v in registry['excluded_paths'].items() if not k.startswith(PREFIX)}
    if before != after: raise ValueError('Unrelated density registry changed')
    before = original(directory+'outputs.json')
    after = read_json(PROJECT/(directory+'outputs.json'))
    before = {k:v for k,v in before.items() if not k.startswith(PREFIX)}
    after = {k:v for k,v in after.items() if not k.startswith(PREFIX)}
    if before != after: raise ValueError('Unrelated density outputs changed')
    identity = 'spec/art_identity/registry.json'
    before_identity, after_identity = original(identity), read_json(PROJECT/identity)
    for registry in (before_identity, after_identity):
        registry['entries'] = [e for e in registry['entries'] if not e.get('path', '').startswith(PREFIX)]
    if before_identity != after_identity: raise ValueError('Unrelated art identity records changed')
    changed = subprocess.check_output(['git', 'diff', '--name-only'], cwd=PROJECT, text=True).splitlines()
    foreign = [p for p in changed if
        (p.startswith('assets/units/') and not p.startswith(PREFIX)) or
        p.startswith(('tools/humanoid_cutout/', 'scripts/maquette_cutout_runtime/', 'spec/peer_benchmark/staged/')) or
        p.startswith(PREFIX+'humanoid_v2/rear')]
    if foreign: raise ValueError('Protected/unrelated files changed: '+str(foreign))
    result = {'ok':True, 'unrelated_density_records_unchanged':len(before),
        'unrelated_identity_records_unchanged':len(before_identity['entries']),
        'other_unit_assets_unchanged':True, 'rear_assets_unchanged':True,
        'generic_rig_code_unchanged':True, 'protected_director_files_unchanged':True}
    write_json(CASE/'proof/rr41_scope.json', result)
    print(f'RR41 SCOPE: PASS ({len(before)} unrelated density records unchanged; other figures, rear and generic code byte-identical)')
    return result


if __name__ == '__main__': verify()
