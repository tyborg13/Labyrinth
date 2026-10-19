"""Hash the protected figures/paint/motion; permit only Thrall registry records."""
import hashlib
import json
from pathlib import Path
import subprocess

from rr24_build import PROJECT, RECIPE, read_json, write_json


def protected(path):
    return (path.startswith(('assets/units/','experiments/cutouts/'))
            and not path.startswith(('assets/units/arc_thrall_cutout/','experiments/cutouts/arc_thrall/'))
            or path.startswith('spec/art_identity/jobs/arc_thrall/')
            or path=='spec/peer_benchmark/staged/rr-11/motion_tracks.json')


def main():
    paths=subprocess.check_output(['git','ls-files'],cwd=PROJECT,text=True).splitlines()
    current={p:hashlib.sha256((PROJECT/p).read_bytes()).hexdigest()
             for p in paths if protected(p) and (PROJECT/p).is_file()}
    digest=hashlib.sha256()
    for name,value in sorted(current.items()): digest.update((name+'\0'+value+'\n').encode())
    expected=read_json(RECIPE/'protected.json')
    errors=[]
    if len(current)!=expected['files'] or digest.hexdigest()!=expected['sha256']:
        errors.append('Protected figures/paint/motion differ')
    # Shared JSON files are owned only at the Thrall entry/key level.
    for relative in ('spec/art_identity/registry.json','spec/assets/board_pixel_density/registry.json',
                     'spec/assets/board_pixel_density/outputs.json'):
        before=json.loads(subprocess.check_output(['git','show','HEAD:'+relative],cwd=PROJECT))
        after=read_json(PROJECT/relative)
        if 'entries' in before:
            for value in (before,after):
                value['entries']=[e for e in value['entries'] if e.get('id') not in ('arc_thrall','arc_thrall_cutout')]
                if 'excluded_paths' in value:
                    value['excluded_paths']={k:v for k,v in value['excluded_paths'].items() if '/arc_thrall_cutout/' not in k}
        else:
            before={k:v for k,v in before.items() if '/arc_thrall_cutout/' not in k}
            after={k:v for k,v in after.items() if '/arc_thrall_cutout/' not in k}
        if before!=after: errors.append('Unrelated registry record changed: '+relative)
    write_json(RECIPE/'preservation.json',{'ok':not errors,'files':len(current),
        'sha256':digest.hexdigest(),'errors':errors})
    print(f'RR24 PROTECTED IDENTITY: {"FAIL" if errors else "PASS"} ({len(current)} files; unrelated registry records retained)')
    for error in errors: print(error)
    return int(bool(errors))


if __name__=='__main__': raise SystemExit(main())
