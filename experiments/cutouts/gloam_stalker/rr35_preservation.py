"""Verify untouched rigs/approved inputs and foreign registration records."""
import json
import subprocess
from rr35_case import PROJECT, CASE
from rr35_baseline import BASE_REVISION, SOURCE_SHA256, read_source
from cutout_pipeline.cases import read_json, write_json, digest

GENERIC_CHANGES = ['tools/humanoid_cutout/anatomy.schema.json', 'tools/humanoid_cutout/walk_gates.py', 'tools/humanoid_cutout/reach.py']
PREFIX = 'assets/units/gloam_stalker_cutout/'


def base_json(path):
    return json.loads(read_source(path))


def check():
    before = read_json(CASE / 'proof/preservation_before.json')
    changed = [p for p, expected in before.items() if not (PROJECT / p).is_file() or digest(PROJECT / p) != expected]
    # Director feedback replaces only the protected motion source. Bind this exception
    # to both the supplied immutable copy and the final bounded-edit receipt.
    authorized = {}
    feedback_path = CASE / 'proof/feedback2_inputs.json'
    if not feedback_path.exists(): feedback_path = CASE / 'proof/feedback1_inputs.json'
    if feedback_path.exists():
        feedback = read_json(feedback_path)
        supplied = CASE / 'proof' / feedback['director_supplied_copy']
        motion = 'spec/peer_benchmark/staged/rr-35/motion_tracks.json'
        if (digest(supplied) == feedback['director_supplied_sha256'] and
                digest(PROJECT / motion) == feedback.get('final_staged_sha256')):
            authorized[motion] = {'supplied_sha256': feedback['director_supplied_sha256'],
                                  'final_sha256': feedback['final_staged_sha256']}
    errors = [p for p in changed if p not in GENERIC_CHANGES and p not in authorized]
    # The accepted rr-35 source cut and density paint must also remain exact.
    round0 = CASE / 'proof/round0/samples.json'
    cut_paint = {}
    unchanged_cut_paint = {}
    repair_path = CASE / 'proof/rr36_preservation.json'
    repair = read_json(repair_path) if repair_path.exists() else {}
    authorized_parts = repair.get('authorized_derived_partitions', {})
    if round0.exists():
        for path, expected in read_json(round0)['inputs'].items():
            if not path.endswith('.png'): continue
            file = PROJECT / path[len('production:'):] if path.startswith('production:') else CASE / path
            cut_paint[path] = file.is_file() and digest(file) == expected
            unchanged_cut_paint[path] = cut_paint[path]
            if path in authorized_parts:
                record = authorized_parts[path]
                cut_paint[path] = (record['before_sha256'] == expected and file.is_file() and
                                   digest(file) == record['after_sha256'])
        errors += ['accepted cut paint changed: ' + p for p, ok in cut_paint.items() if not ok]
    foreign = {}
    path = 'spec/art_identity/registry.json'
    selector = lambda d: [e for e in d['entries'] if not e['path'].startswith(PREFIX)]
    foreign[path] = selector(base_json(path)) == selector(read_json(PROJECT / path))
    path = 'spec/assets/board_pixel_density/registry.json'
    def registry(d):
        d['entries'] = [e for e in d['entries'] if e['id'] != 'gloam_stalker_cutout']
        d['excluded_paths'] = {k: v for k, v in d['excluded_paths'].items() if not k.startswith(PREFIX)}
        return d
    foreign[path] = registry(base_json(path)) == registry(read_json(PROJECT / path))
    path = 'spec/assets/board_pixel_density/outputs.json'
    selector = lambda d: {k: v for k, v in d.items() if not k.startswith(PREFIX)}
    foreign[path] = selector(base_json(path)) == selector(read_json(PROJECT / path))
    for path, ok in foreign.items():
        if not ok: errors.append('foreign registration changed: ' + path)
    # Include import sidecars in the Git scope check, beyond the source hash set.
    paths = subprocess.check_output(['git', 'diff', '--name-only', '--', 'assets/units'], cwd=PROJECT, text=True).splitlines()
    errors += [p for p in paths if not p.startswith(PREFIX)]
    report = {'ok': not errors, 'errors': errors, 'protected_files_checked': len(before),
              'baseline_revision': BASE_REVISION, 'baseline_source_sha256': SOURCE_SHA256,
              'generic_changes': [p for p in changed if p in GENERIC_CHANGES],
              'generic_additions': ['tools/humanoid_cutout/reach_policy.py'],
              'authorized_director_replacements': authorized,
              'accepted_cut_pngs_checked': len(cut_paint), 'accepted_cut_pngs_unchanged': all(unchanged_cut_paint.values()),
              'accepted_cut_pngs_match_authorized_baseline': all(cut_paint.values()),
              'rr36_authorized_derived_partitions': authorized_parts,
              'rest_baseline_reconciliation': repair.get('rest_baseline_reconciliation', {}),
              'foreign_records_unchanged': foreign,
              'other_unit_git_changes': [p for p in paths if not p.startswith(PREFIX)]}
    write_json(CASE / 'proof/preservation.json', report)
    print('RR35 PRESERVATION: %s (%d protected files; %d expected generic changes)' %
          ('PASS' if report['ok'] else 'FAIL', len(before), len([p for p in changed if p in GENERIC_CHANGES])))
    for error in errors: print(error)
    return report


if __name__ == '__main__': raise SystemExit(not check()['ok'])
