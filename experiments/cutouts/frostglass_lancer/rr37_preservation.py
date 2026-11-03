"""Read-only audit of protected inputs, every other rig, and foreign records."""
import json
import subprocess
from rr37_case import PROJECT, CASE
from cutout_pipeline.cases import digest, read_json, write_json

OWN='assets/units/frostglass_lancer_cutout/'
GENERIC_CHANGES=['tools/humanoid_cutout/anatomy.schema.json', 'tools/humanoid_cutout/source_view.py']
OUTLINE_JOB_OUTPUTS={
    'spec/art_identity/jobs/frostglass_lancer/mq14_rear_v2/'+name
    for name in ('kit.json','processed.png','processed.json','provenance.json','review_sheet.png','refs/recolour_rear.py')}


def original(path):
    return subprocess.check_output(['git','show','HEAD:'+path],cwd=PROJECT)


def check():
    files=subprocess.check_output(['git','ls-files','-z','assets/units','spec/art_identity/maquettes/frostglass_lancer',
        'spec/art_identity/jobs/frostglass_lancer','spec/peer_benchmark/staged/rr-37'],cwd=PROJECT).decode().split('\0')
    protected=[p for p in files if p and not p.startswith(OWN) and p not in OUTLINE_JOB_OUTPUTS]
    changed=subprocess.check_output(['git','diff','--name-only','--',*protected],cwd=PROJECT,text=True).splitlines()
    foreign={}
    for path in ['spec/art_identity/registry.json','spec/assets/board_pixel_density/registry.json','spec/assets/board_pixel_density/outputs.json']:
        before=json.loads(original(path));after=read_json(PROJECT/path)
        if path.endswith('outputs.json'):
            strip=lambda d:{k:v for k,v in d.items() if not k.startswith(OWN)}
        elif 'board_pixel_density' in path:
            def strip(d):
                d['entries']=[e for e in d['entries'] if not e.get('dir', '').startswith('assets/units/frostglass_lancer_cutout')]
                d['excluded_paths']={k:v for k,v in d['excluded_paths'].items() if not k.startswith(OWN)}
                return d
        else: strip=lambda d:[e for e in d['entries'] if not e.get('path','').startswith(OWN)]
        foreign[path]=strip(before)==strip(after)
    errors=changed+['foreign records changed: '+p for p,ok in foreign.items() if not ok]
    result={'ok':not errors,'errors':errors,'protected_files_checked':len(protected),
        'other_rigs_byte_identical':not changed,'foreign_records_unchanged':foreign,'generic_changes':GENERIC_CHANGES}
    write_json(CASE/'proof/preservation.json',result)
    print('RR37 PRESERVATION: %s (%d protected files; other rigs byte-identical)' % ('FAIL' if errors else 'PASS',len(protected)))
    for error in errors: print(error)
    return result


if __name__=='__main__': raise SystemExit(not check()['ok'])
