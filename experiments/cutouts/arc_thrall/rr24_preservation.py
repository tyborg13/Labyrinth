"""Protect rr-24's historical scope and the live approved Thrall inputs."""
import subprocess

from rr24_build import PROJECT, RECIPE, write_json
from unit_preservation import changed_paths, read_bytes, read_json as revision_json, tracked_paths

BASELINE_COMMIT = '521fa8f204f6f3b5d0aca1d09ec2494107c155d9'
UNIT_HEAD = '288107b25febff414c267e058c5fb2857f23294b'
OWN_INPUT_PREFIX = 'spec/art_identity/jobs/arc_thrall/'
OWN_DIRECTOR = 'spec/peer_benchmark/staged/rr-11/motion_tracks.json'
SHARED_RECORDS = ('spec/art_identity/registry.json','spec/assets/board_pixel_density/registry.json',
                  'spec/assets/board_pixel_density/outputs.json')


def protected(path):
    return (path.startswith(('assets/units/','experiments/cutouts/'))
            and not path.startswith(('assets/units/arc_thrall_cutout/','experiments/cutouts/arc_thrall/'))
            or path.startswith(OWN_INPUT_PREFIX) or path==OWN_DIRECTOR)


def preservation_errors(project=PROJECT, baseline=BASELINE_COMMIT, end=UNIT_HEAD):
    # The aggregate protected.json remains historical evidence. A range diff
    # also catches added/deleted files without pinning later units' output.
    errors=['Protected figures/paint/motion differ: '+p
            for p in changed_paths(project,baseline,end) if protected(p)]
    # Own approved jobs and director bytes keep their live preservation guard.
    original=set(tracked_paths(project,baseline,OWN_INPUT_PREFIX)+tracked_paths(project,baseline,OWN_DIRECTOR))
    live=subprocess.check_output(['git','ls-files','-z','--',OWN_INPUT_PREFIX,OWN_DIRECTOR],cwd=project).decode().split('\0')
    for name in sorted(original | {p for p in live if p}):
        path=project/name
        if name not in original or not path.is_file() or path.read_bytes()!=read_bytes(project,baseline,name):
            errors.append('Protected Thrall input changed: '+name)
    # Shared JSON files are owned only at the Thrall entry/key level.
    for relative in SHARED_RECORDS:
        before=revision_json(project,baseline,relative)
        after=revision_json(project,end,relative)
        if 'entries' in before:
            for value in (before,after):
                value['entries']=[e for e in value['entries'] if e.get('id') not in ('arc_thrall','arc_thrall_cutout')]
                if 'excluded_paths' in value:
                    value['excluded_paths']={k:v for k,v in value['excluded_paths'].items() if '/arc_thrall_cutout/' not in k}
        else:
            before={k:v for k,v in before.items() if '/arc_thrall_cutout/' not in k}
            after={k:v for k,v in after.items() if '/arc_thrall_cutout/' not in k}
        if before!=after: errors.append('Unrelated registry record changed: '+relative)
    return errors


def main():
    errors=preservation_errors()
    write_json(RECIPE/'preservation.json',{'ok':not errors,'base_commit':BASELINE_COMMIT,
        'unit_head':UNIT_HEAD,'errors':errors})
    print(f'RR24 PROTECTED IDENTITY: {"FAIL" if errors else "PASS"} (pinned unit range; unrelated registry records retained)')
    for error in errors: print(error)
    return int(bool(errors))


if __name__=='__main__': raise SystemExit(main())
